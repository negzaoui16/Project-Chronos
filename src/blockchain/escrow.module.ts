import { Module, forwardRef } from '@nestjs/common';
import { WalletModule } from '../wallet/wallet.module';
import { EscrowService } from './escrow.service';

/**
 * Escrow operations depend on WalletService (custodial decrypt).
 * WalletModule also imports EscrowModule for on-chain history — use forwardRef.
 */
@Module({
  imports: [forwardRef(() => WalletModule)],
  providers: [EscrowService],
  exports: [EscrowService],
})
export class EscrowModule {}
