import {
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Prisma, User } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CloudinaryService } from '../../common/cloudinary/cloudinary.service';
import {
  BlockchainService,
  MintInitialTokensResult,
  MintInitialTokensError,
} from '../../blockchain/blockchain.service';
import { WalletService } from '../../wallet/wallet.service';
import { MailService } from './mail.service';
import * as crypto from 'crypto';

// Authentication and password recovery logic
@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly cloudinaryService: CloudinaryService,
    private readonly mailService: MailService,
    private readonly walletService: WalletService,
    private readonly blockchainService: BlockchainService,
  ) {}

  private hashPassword(password: string): string {
    return crypto.createHmac('sha256', 'chronos-salt').update(password).digest('hex');
  }

  async register(dto: any, file: Express.Multer.File) {
    let createdUserId: string | null = null;
    let confirmedMint: MintInitialTokensResult | null = null;

    try {
      const existingUser = await this.prisma.user.findFirst({
        where: {
          OR: [
            { email: dto.email },
            { studentId: dto.studentId },
          ],
        },
      });

      if (existingUser) {
        throw new ConflictException('User with this email or student ID already exists');
      }

      // Upload profile image to Cloudinary
      let profileImageUrl = 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png';
      if (file) {
        try {
          profileImageUrl = await this.cloudinaryService.uploadImage(file);
        } catch (uploadError) {
          // Fallback placeholder avatar if upload fails
        }
      }

      const hashedPassword = this.hashPassword(dto.password);
      const wallet = this.walletService.generateWallet();
      const encryptedPrivateKey = this.walletService.encryptPrivateKey(
        wallet.privateKey,
      );

      const user = await this.prisma.user.create({
        data: {
          email: dto.email,
          password: hashedPassword,
          name: dto.name,
          studentId: dto.studentId,
          // Public registration always creates a student account.
          role: 'STUDENT',
          reputationScore: 100.0,
          profileImageUrl: profileImageUrl,
          walletAddress: wallet.address,
          encryptedPrivateKey,
          tokenMintStatus: 'PENDING',
        },
      });
      createdUserId = user.id;

      try {
        confirmedMint = await this.blockchainService.mintInitialTokens(
          wallet.address,
        );
      } catch (error: unknown) {
        this.logger.error(
          `Blockchain mint initial tokens failed during registration: ${error instanceof Error ? error.message : String(error)}`,
        );
        await this.handleMintFailure(user.id, error);
      }

      let confirmedUser = user;
      if (confirmedMint) {
        // Polygon has confirmed the mint.
        confirmedUser = await this.prisma.user.update({
          where: { id: user.id },
          data: {
            tokenMintStatus: 'CONFIRMED',
            tokenMintTransactionHash: confirmedMint.transactionHash,
            tokenMintBlockNumber: confirmedMint.blockNumber,
            tokenMintError: null,
            tokenMintedAt: new Date(),
          },
        });
      }

      const payload = {
        sub: confirmedUser.id,
        email: confirmedUser.email,
        role: confirmedUser.role,
      };
      const token = this.jwtService.sign(payload);
      const chronosBalance = await this.getBalanceSafely(wallet.address);

      return {
        token,
        user: this.toSafeUser(confirmedUser, chronosBalance),
      };
    } catch (error: unknown) {
      if (
        error instanceof ConflictException ||
        error instanceof ServiceUnavailableException
      ) {
        throw error;
      }

      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException(
          'User with this email or student ID already exists',
        );
      }

      if (createdUserId && confirmedMint) {
        // Polygon is already final. Never compensate by deleting this wallet;
        // retry the confirmation write and surface a recoverable server error.
        await this.prisma.user
          .update({
            where: { id: createdUserId },
            data: {
              tokenMintStatus: 'CONFIRMED',
              tokenMintTransactionHash: confirmedMint.transactionHash,
              tokenMintBlockNumber: confirmedMint.blockNumber,
              tokenMintError: null,
              tokenMintedAt: new Date(),
            },
          })
          .catch((updateError: unknown) => {
            this.logger.error(
              `Polygon mint confirmed but database reconciliation failed for ${createdUserId}: ${this.errorMessage(updateError)}`,
            );
          });

        throw new ServiceUnavailableException(
          'Tokens were minted, but registration finalization must be retried.',
        );
      }

      // If creation succeeded but a pre-broadcast mint failure occurred,
      // handleMintFailure already removed the user as compensation.
      this.logger.error(
        `Registration failed${createdUserId ? ` for ${createdUserId}` : ''}: ${this.errorMessage(error)}`,
      );
      throw new ServiceUnavailableException(
        `Registration failed: ${this.errorMessage(error)}`,
      );
    }
  }

  async login(dto: any) {
    let user;
    try {
      user = await this.prisma.user.findUnique({
        where: { email: dto.email },
      });
    } catch (error) {
      throw new ServiceUnavailableException('Database connection failed. Cannot validate login.');
    }

    if (!user) {
      throw new UnauthorizedException('No account associated with this email address');
    }

    const hashedPassword = this.hashPassword(dto.password);
    if (user.password !== hashedPassword) {
      throw new UnauthorizedException('Invalid email or password combination');
    }

    // Reconcile an ambiguous submitted transaction without minting again.
    if (user.walletAddress && user.tokenMintStatus === 'SUBMITTED') {
      try {
        const minted =
          await this.blockchainService.hasReceivedInitialTokens(
            user.walletAddress,
          );
        if (minted) {
          user = await this.prisma.user.update({
            where: { id: user.id },
            data: {
              tokenMintStatus: 'CONFIRMED',
              tokenMintError: null,
              tokenMintedAt: new Date(),
            },
          });
        }
      } catch (error: unknown) {
        this.logger.warn(
          `Unable to reconcile token mint for ${user.id}: ${this.errorMessage(error)}`,
        );
      }
    }

    const payload = { sub: user.id, email: user.email, role: user.role };
    const token = this.jwtService.sign(payload);

    const chronosBalance = user.walletAddress
      ? await this.getBalanceSafely(user.walletAddress)
      : null;

    return {
      token,
      user: this.toSafeUser(user, chronosBalance),
    };
  }

  async forgotPassword(dto: { email: string }) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });

    if (!user) {
      throw new NotFoundException('No account registered with this email address');
    }

    // Generate 4-digit verification code
    const resetCode = (Math.floor(1000 + Math.random() * 9000)).toString();
    const resetCodeExpires = new Date(Date.now() + 15 * 60 * 1000); // 15 mins validity

    try {
      await this.prisma.user.update({
        where: { email: dto.email },
        data: {
          resetCode,
          resetCodeExpires,
        },
      });

      await this.mailService.sendResetCode(dto.email, resetCode);
      return { message: 'A 4-digit security code has been sent to your email.' };
    } catch (error: any) {
      throw new ServiceUnavailableException('Failed to process forgot password: ' + error.message);
    }
  }

  async resetPassword(dto: any) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });

    if (!user) {
      throw new NotFoundException('No account registered with this email address');
    }

    if (!user.resetCode || !user.resetCodeExpires || user.resetCode !== dto.code) {
      throw new UnauthorizedException('Invalid verification code');
    }

    if (new Date() > user.resetCodeExpires) {
      throw new UnauthorizedException('Verification code has expired');
    }

    const hashedPassword = this.hashPassword(dto.newPassword);

    try {
      await this.prisma.user.update({
        where: { email: dto.email },
        data: {
          password: hashedPassword,
          resetCode: null,
          resetCodeExpires: null,
        },
      });
      return { message: 'Password has been reset successfully.' };
    } catch (error: any) {
      throw new ServiceUnavailableException('Failed to update password: ' + error.message);
    }
  }

  private async handleMintFailure(
    userId: string,
    error: unknown,
  ): Promise<never> {
    const message = this.errorMessage(error);

    if (error instanceof MintInitialTokensError && error.submitted) {
      // The transaction may still confirm. Keep the immutable wallet and
      // record the hash so it can be reconciled safely instead of minting
      // again or generating a replacement wallet.
      await this.prisma.user.update({
        where: { id: userId },
        data: {
          tokenMintStatus: 'SUBMITTED',
          tokenMintTransactionHash: error.transactionHash,
          tokenMintError: message,
        },
      });

      throw new ServiceUnavailableException(
        'Registration wallet was created and token minting was submitted. Confirmation is still pending.',
      );
    }

    try {
      // No transaction was broadcast, so removing the just-created user is a
      // safe compensation and allows registration to be retried cleanly.
      await this.prisma.user.delete({ where: { id: userId } });
    } catch (compensationError: unknown) {
      this.logger.error(
        `Failed to compensate registration for ${userId}: ${this.errorMessage(compensationError)}`,
      );

      await this.prisma.user
        .update({
          where: { id: userId },
          data: {
            tokenMintStatus: 'FAILED',
            tokenMintError: message,
          },
        })
        .catch(() => undefined);
    }

    throw new ServiceUnavailableException(
      `Registration rolled back because initial token minting failed: ${message}`,
    );
  }

  private async getBalanceSafely(
    walletAddress: string,
  ): Promise<string | null> {
    try {
      return await this.blockchainService.getBalance(walletAddress);
    } catch (error: unknown) {
      this.logger.warn(
        `Unable to read CHRONOS balance for ${walletAddress}: ${this.errorMessage(error)}`,
      );
      return null;
    }
  }

  private toSafeUser(user: User, chronosBalance: string | null) {
    const {
      password: _password,
      encryptedPrivateKey: _encryptedPrivateKey,
      resetCode: _resetCode,
      resetCodeExpires: _resetCodeExpires,
      tokenMintError: _tokenMintError,
      ...safeUser
    } = user;

    return {
      ...safeUser,
      chronosBalance,
    };
  }

  private errorMessage(error: unknown): string {
    return error instanceof Error ? error.message : String(error);
  }

  async validateUserById(id: string) {
    try {
      return await this.prisma.user.findUnique({
        where: { id },
        select: {
          id: true,
          email: true,
          name: true,
          studentId: true,
          role: true,
          reputationScore: true,
          profileImageUrl: true,
          walletAddress: true,
          tokenMintStatus: true,
          tokenMintTransactionHash: true,
        },
      });
    } catch (e) {
      return null;
    }
  }
}
