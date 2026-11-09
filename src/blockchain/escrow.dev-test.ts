import 'dotenv/config';
import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { BlockchainService } from './blockchain.service';
import { EscrowService } from './escrow.service';
import { WalletService } from '../wallet/wallet.service';

const DEPOSIT_AMOUNT = '20';

/**
 * Temporary development script — full escrow happy path on Polygon Amoy.
 *
 * Prerequisites:
 *   - ESCROW_ADDRESS, CHRONOS_TOKEN_ADDRESS, RPC_URL, ADMIN_PRIVATE_KEY in .env
 *   - At least one STUDENT user with wallet + enough CHRONOS balance
 *   - Admin wallet has OPERATOR_ROLE on ReservationEscrow and POL for gas
 *   - Student wallet has POL for the approve transaction gas
 *
 * Usage:
 *   npx ts-node -r tsconfig-paths/register src/blockchain/escrow.dev-test.ts
 *   npm run escrow:test
 */
async function main(): Promise<void> {
  const config = new ConfigService();
  const prisma = new PrismaClient() as unknown as PrismaService;

  const blockchainService = new BlockchainService(config);
  const walletService = new WalletService(
    config,
    prisma,
    blockchainService,
    {} as EscrowService,
  );
  const escrowService = new EscrowService(config, prisma, walletService);

  console.log('================================================');
  console.log(' Chronos — ReservationEscrow Dev Test');
  console.log('================================================');
  console.log(` Token  : ${escrowService.getTokenAddress()}`);
  console.log(` Escrow : ${escrowService.getEscrowAddress()}`);
  console.log('------------------------------------------------');

  const student = await prisma.user.findFirst({
    where: {
      role: 'STUDENT',
      walletAddress: { not: null },
      encryptedPrivateKey: { not: null },
    },
    orderBy: { tokenMintedAt: 'desc' },
    select: {
      id: true,
      email: true,
      walletAddress: true,
    },
  });

  if (!student?.walletAddress) {
    throw new Error(
      'No student with a custodial wallet found. Register a student first.',
    );
  }

  console.log(` Student userId : ${student.id}`);
  console.log(` Student email  : ${student.email}`);
  console.log(` Student wallet : ${student.walletAddress}`);

  const balanceBefore = await escrowService.getStudentBalance(student.id);
  console.log(` Balance before : ${balanceBefore} CHRONOS`);
  console.log('------------------------------------------------');

  console.log(`1) Approve escrow for ${DEPOSIT_AMOUNT} CHRONOS...`);
  const approve = await escrowService.approveEscrow(student.id, DEPOSIT_AMOUNT);
  console.log(`   approve tx : ${approve.transactionHash}`);
  console.log(`   block      : ${approve.blockNumber}`);

  console.log(`2) Create reservation for ${DEPOSIT_AMOUNT} CHRONOS...`);
  // createReservation also re-approves (idempotent allowance set); that is expected.
  const created = await escrowService.createReservation(
    student.id,
    DEPOSIT_AMOUNT,
  );
  console.log(`   reservationId : ${created.reservationId}`);
  console.log(`   create tx     : ${created.transactionHash}`);
  console.log(`   block         : ${created.blockNumber}`);

  console.log('3) Verify reservation on-chain...');
  const reservation = await escrowService.getReservation(created.reservationId);
  console.log(`   active   : ${reservation.active}`);
  console.log(`   student  : ${reservation.student}`);
  console.log(`   deposit  : ${reservation.depositAmount} CHRONOS`);
  console.log(
    `   locked   : ${await escrowService.getLockedBalance()} CHRONOS`,
  );

  if (!reservation.active) {
    throw new Error('Reservation should be active after create');
  }

  const midBalance = await escrowService.getStudentBalance(student.id);
  console.log(`   balance after lock : ${midBalance} CHRONOS`);

  console.log('4) Release reservation...');
  const released = await escrowService.releaseReservation(created.reservationId);
  console.log(`   release tx : ${released.transactionHash}`);
  console.log(`   block      : ${released.blockNumber}`);
  console.log(`   status     : ${released.status}`);

  console.log('5) Verify student balance restored...');
  const after = await escrowService.getReservation(created.reservationId);
  const balanceAfter = await escrowService.getStudentBalance(student.id);
  console.log(`   active   : ${after.active}`);
  console.log(`   released : ${after.released}`);
  console.log(`   balance after release : ${balanceAfter} CHRONOS`);

  if (after.active || !after.released) {
    throw new Error('Reservation should be inactive and released');
  }

  console.log('================================================');
  console.log(' Escrow happy-path completed successfully');
  console.log('================================================');
  console.log(' Transaction hashes:');
  console.log(`   approve  : ${approve.transactionHash}`);
  console.log(`   create   : ${created.transactionHash}`);
  console.log(`   release  : ${released.transactionHash}`);
  console.log('================================================');

  await prisma.$disconnect();
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
