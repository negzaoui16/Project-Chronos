import 'dotenv/config';
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { BlockchainService } from './blockchain.service';
import { EscrowService } from './escrow.service';
import { WalletService } from '../wallet/wallet.service';

async function main(): Promise<void> {
  const config = new ConfigService();
  const prisma = new PrismaClient() as unknown as PrismaService;
  const blockchain = new BlockchainService(config);

  // Resolve circular WalletService <-> EscrowService for the script.
  let escrowService!: EscrowService;
  const walletService = new WalletService(config, prisma, blockchain, {
    getOnChainHistory: (address: string, limit?: number) =>
      escrowService.getOnChainHistory(address, limit),
    getEscrowAddress: () => escrowService.getEscrowAddress(),
    getTokenAddress: () => escrowService.getTokenAddress(),
  } as EscrowService);
  escrowService = new EscrowService(config, prisma, walletService);

  const student = await prisma.user.findFirst({
    where: {
      role: 'STUDENT',
      walletAddress: { not: null },
    },
    orderBy: { tokenMintedAt: 'desc' },
    select: { id: true, email: true, walletAddress: true },
  });

  if (!student?.walletAddress) {
    throw new Error('No student with a wallet found');
  }

  console.log('================================================');
  console.log(' On-chain wallet history test');
  console.log('================================================');
  console.log(` Student : ${student.email}`);
  console.log(` UserId  : ${student.id}`);
  console.log(` Wallet  : ${student.walletAddress}`);
  console.log(` Escrow  : ${escrowService.getEscrowAddress()}`);
  console.log(` Token   : ${escrowService.getTokenAddress()}`);
  console.log('------------------------------------------------');

  const result = await walletService.getTransactionHistory(student.id, 20);

  console.log(` items   : ${result.items.length}`);
  console.log('------------------------------------------------');

  if (result.items.length === 0) {
    throw new Error('Expected at least one on-chain history item');
  }

  for (const item of result.items) {
    console.log(
      [
        item.type.padEnd(14),
        `res=${item.reservationId ?? '-'}`,
        `amount=${item.amount ?? '-'}`,
        `block=${item.blockNumber ?? '-'}`,
        item.transactionHash ?? '(no hash)',
      ].join(' | '),
    );
    if (item.explorerUrl) {
      console.log(`   ${item.explorerUrl}`);
    }
  }

  const types = new Set(result.items.map((item) => item.type));
  console.log('================================================');
  console.log(` Types found: ${[...types].join(', ')}`);
  console.log(' On-chain wallet history OK');
  console.log('================================================');

  await prisma.$disconnect();
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
