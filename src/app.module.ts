import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { ChronosBackendModule } from './module1/chronos-backend/chronos-backend.module';
import { Module2ApiModule } from './module2/module2-api/module2-api.module';
import { AuthModule } from './module3/auth/auth.module';
import { GatewayRagModule } from './module3/gateway-rag/gateway-rag.module';
import { ChatModule } from './module3/chat/chat.module';
import { AssetsModule } from './assets/assets.module';
import { BookingsModule } from './bookings/bookings.module';
import { WalletModule } from './wallet/wallet.module';
import { EscrowModule } from './blockchain/escrow.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    PrismaModule,
    ChronosBackendModule,
    Module2ApiModule,
    AuthModule,
    GatewayRagModule,
    ChatModule,
    AssetsModule,
    BookingsModule,
    WalletModule,
    EscrowModule,
  ],
})
export class AppModule {}
