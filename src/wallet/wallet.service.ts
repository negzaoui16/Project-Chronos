import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
  forwardRef,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  createCipheriv,
  createDecipheriv,
  randomBytes,
  timingSafeEqual,
} from 'node:crypto';
import { Wallet } from 'ethers';
import { BlockchainService } from '../blockchain/blockchain.service';
import { EscrowService } from '../blockchain/escrow.service';
import { PrismaService } from '../prisma/prisma.service';

const ENCRYPTION_ALGORITHM = 'aes-256-gcm';
const ENCRYPTION_VERSION = 'v1';
const IV_LENGTH_BYTES = 12;
const AUTH_TAG_LENGTH_BYTES = 16;

export interface GeneratedWallet {
  address: string;
  privateKey: string;
  publicKey: string;
}

export interface StoredWallet {
  address: string;
  publicKey: string;
}

@Injectable()
export class WalletService {
  private readonly logger = new Logger(WalletService.name);
  private readonly encryptionKey: Buffer;

  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
    private readonly blockchainService: BlockchainService,
    @Inject(forwardRef(() => EscrowService))
    private readonly escrowService: EscrowService,
  ) {
    // Validate the key when Nest creates the service so configuration errors
    // fail fast rather than appearing during the first student registration.
    this.encryptionKey = this.loadEncryptionKey();
  }

  /**
   * Generates a local Ethereum-compatible wallet.
   *
   * This operation only uses cryptographically secure local randomness. It
   * does not connect to Polygon, submit a transaction, or consume gas.
   */
  generateWallet(): GeneratedWallet {
    const wallet = Wallet.createRandom();

    return {
      address: wallet.address,
      privateKey: wallet.privateKey,
      publicKey: wallet.signingKey.publicKey,
    };
  }

  /**
   * Encrypts a private key with AES-256-GCM.
   *
   * The returned value contains a format version, a random IV, the
   * authentication tag, and the ciphertext. The encryption key is never
   * included and must come from ENCRYPTION_KEY.
   */
  encryptPrivateKey(privateKey: string): string {
    const iv = randomBytes(IV_LENGTH_BYTES);
    const cipher = createCipheriv(
      ENCRYPTION_ALGORITHM,
      this.encryptionKey,
      iv,
    );

    const encrypted = Buffer.concat([
      cipher.update(privateKey, 'utf8'),
      cipher.final(),
    ]);
    const authTag = cipher.getAuthTag();

    return [
      ENCRYPTION_VERSION,
      iv.toString('base64'),
      authTag.toString('base64'),
      encrypted.toString('base64'),
    ].join(':');
  }

  /**
   * Decrypts and authenticates a value produced by encryptPrivateKey().
   */
  decryptPrivateKey(encryptedPrivateKey: string): string {
    const [version, ivValue, authTagValue, encryptedValue, ...extraParts] =
      encryptedPrivateKey.split(':');

    if (
      version !== ENCRYPTION_VERSION ||
      !ivValue ||
      !authTagValue ||
      !encryptedValue ||
      extraParts.length > 0
    ) {
      throw new Error('Invalid encrypted private key format');
    }

    const iv = Buffer.from(ivValue, 'base64');
    const authTag = Buffer.from(authTagValue, 'base64');
    const encrypted = Buffer.from(encryptedValue, 'base64');

    if (
      iv.length !== IV_LENGTH_BYTES ||
      authTag.length !== AUTH_TAG_LENGTH_BYTES
    ) {
      throw new Error('Invalid encrypted private key metadata');
    }

    try {
      const decipher = createDecipheriv(
        ENCRYPTION_ALGORITHM,
        this.encryptionKey,
        iv,
      );
      decipher.setAuthTag(authTag);

      return Buffer.concat([
        decipher.update(encrypted),
        decipher.final(),
      ]).toString('utf8');
    } catch {
      throw new Error('Unable to decrypt private key');
    }
  }

  /**
   * Creates and stores a wallet for an existing student.
   *
   * Only the address and encrypted private key are persisted. The plaintext
   * private key and mnemonic are never written to the database.
   */
  async createAndStoreWallet(studentUserId: string): Promise<StoredWallet> {
    const student = await this.prisma.user.findUnique({
      where: { id: studentUserId },
      select: {
        id: true,
        role: true,
        walletAddress: true,
      },
    });

    if (!student) {
      throw new NotFoundException('Student not found');
    }

    if (student.role !== 'STUDENT') {
      throw new BadRequestException('Wallets can only be created for students');
    }

    if (student.walletAddress) {
      throw new ConflictException('Student already has a wallet');
    }

    const wallet = this.generateWallet();
    const encryptedPrivateKey = this.encryptPrivateKey(wallet.privateKey);

    // The null condition prevents concurrent requests from replacing a wallet.
    const result = await this.prisma.user.updateMany({
      where: {
        id: student.id,
        walletAddress: null,
      },
      data: {
        walletAddress: wallet.address,
        encryptedPrivateKey,
      },
    });

    if (result.count !== 1) {
      throw new ConflictException('Student already has a wallet');
    }

    return {
      address: wallet.address,
      publicKey: wallet.publicKey,
    };
  }

  /**
   * Returns the authenticated user's wallet metadata and live CHRONOS balance.
   * No private-key material is selected from or returned by this method.
   */
  async getWalletOverview(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        walletAddress: true,
        tokenMintStatus: true,
        tokenMintTransactionHash: true,
        tokenMintBlockNumber: true,
        tokenMintedAt: true,
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (!user.walletAddress) {
      throw new NotFoundException('Wallet has not been provisioned');
    }

    let chronosBalance: string;
    try {
      chronosBalance = await this.blockchainService.getBalance(
        user.walletAddress,
      );
    } catch (error: unknown) {
      this.logger.warn(
        `Unable to read CHRONOS balance for ${user.walletAddress}: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      throw new ServiceUnavailableException(
        'CHRONOS balance is temporarily unavailable',
      );
    }

    const transactionExplorerUrl = user.tokenMintTransactionHash
      ? `https://amoy.polygonscan.com/tx/${user.tokenMintTransactionHash}`
      : null;

    return {
      walletAddress: user.walletAddress,
      chronosBalance,
      tokenName: 'Chronos Token',
      tokenSymbol: 'CHRONOS',
      tokenMintStatus: user.tokenMintStatus,
      tokenMintTransactionHash: user.tokenMintTransactionHash,
      tokenMintBlockNumber: user.tokenMintBlockNumber,
      tokenMintedAt: user.tokenMintedAt,
      walletExplorerUrl: `https://amoy.polygonscan.com/address/${user.walletAddress}`,
      transactionExplorerUrl,
      contractAddress: this.blockchainService.getContractAddress(),
    };
  }

  /**
   * Live on-chain wallet / escrow history for the authenticated student.
   * Queries Polygon Amoy events; does not use a DB transaction ledger.
   */
  async getTransactionHistory(userId: string, limit = 50) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { walletAddress: true },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }
    if (!user.walletAddress) {
      throw new NotFoundException('Wallet has not been provisioned');
    }

    try {
      const items = await this.escrowService.getOnChainHistory(
        user.walletAddress,
        limit,
      );
      return {
        walletAddress: user.walletAddress,
        escrowAddress: this.escrowService.getEscrowAddress(),
        tokenAddress: this.escrowService.getTokenAddress(),
        items,
      };
    } catch (error: unknown) {
      this.logger.warn(
        `Unable to load on-chain history for ${user.walletAddress}: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      throw new ServiceUnavailableException(
        'Wallet transaction history is temporarily unavailable',
      );
    }
  }

  /**
   * Development-only round-trip check for wallet generation and encryption.
   * It does not persist data or interact with a blockchain.
   */
  testWalletEncryption(): {
    walletAddress: string;
    encryptedKey: string;
    success: boolean;
  } {
    const wallet = this.generateWallet();
    const encryptedKey = this.encryptPrivateKey(wallet.privateKey);
    const decryptedKey = this.decryptPrivateKey(encryptedKey);
    const success = timingSafeEqual(
      Buffer.from(decryptedKey),
      Buffer.from(wallet.privateKey),
    );

    this.logger.log(`Wallet Address: ${wallet.address}`);
    this.logger.log(`Encrypted Key: ${encryptedKey}`);
    this.logger.log(`Result: ${success ? 'Success' : 'Failure'}`);

    return {
      walletAddress: wallet.address,
      encryptedKey,
      success,
    };
  }

  private loadEncryptionKey(): Buffer {
    const value = this.configService.get<string>('ENCRYPTION_KEY')?.trim();

    if (!value || !/^[0-9a-fA-F]{64}$/.test(value)) {
      throw new Error(
        'ENCRYPTION_KEY must be configured as exactly 64 hexadecimal characters',
      );
    }

    return Buffer.from(value, 'hex');
  }
}
