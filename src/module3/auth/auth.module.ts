import { Module } from '@nestjs/common';
import { PassportModule } from '@nestjs/passport';
import { JwtModule } from '@nestjs/jwt';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';
import { PrismaModule } from '../../prisma/prisma.module';
import { CloudinaryModule } from '../../common/cloudinary/cloudinary.module';
import { MailService } from './mail.service';
import { WalletModule } from '../../wallet/wallet.module';
import { BlockchainModule } from '../../blockchain/blockchain.module';

@Module({
  imports: [
    PrismaModule,
    PassportModule,
    CloudinaryModule,
    WalletModule,
    BlockchainModule,
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'chronos_secure_jwt_token_2026_secret',
      signOptions: { expiresIn: '1d' },
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy, MailService],
  exports: [AuthService],
})
export class AuthModule {}
