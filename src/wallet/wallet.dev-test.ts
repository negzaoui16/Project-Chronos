import 'dotenv/config';
import { ConfigService } from '@nestjs/config';
import { BlockchainService } from '../blockchain/blockchain.service';
import { PrismaService } from '../prisma/prisma.service';
import { WalletService } from './wallet.service';

/**
 * Temporary development check.
 *
 * Generates a wallet and verifies the AES-256-GCM encryption round trip.
 * It neither persists the wallet nor sends a blockchain transaction.
 */
async function main(): Promise<void> {
  // Prisma is intentionally not initialized because this check does not store
  // anything. Database persistence is exercised later by registration tests.
  const walletService = new WalletService(
    new ConfigService(),
    {} as PrismaService,
    {} as BlockchainService,
    {} as import('../blockchain/escrow.service').EscrowService,
  );
  walletService.testWalletEncryption();
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
