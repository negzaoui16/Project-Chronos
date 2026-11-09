import { Module, forwardRef } from '@nestjs/common';
import { BlockchainModule } from '../blockchain/blockchain.module';
import { EscrowModule } from '../blockchain/escrow.module';
import { WalletController } from './wallet.controller';
import { WalletService } from './wallet.service';

@Module({
  imports: [BlockchainModule, forwardRef(() => EscrowModule)],
  controllers: [WalletController],
  providers: [WalletService],
  exports: [WalletService],
})
export class WalletModule {}
