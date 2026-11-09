import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  Contract,
  ContractTransactionReceipt,
  JsonRpcProvider,
  NonceManager,
  Wallet,
  formatEther,
  formatUnits,
  isAddress,
  parseEther,
  parseUnits,
} from 'ethers';
import { PrismaService } from '../prisma/prisma.service';
import { WalletService } from '../wallet/wallet.service';
import { CHRONOS_TOKEN_ABI } from './chronos-token.abi';
import { RESERVATION_ESCROW_ABI } from './reservation-escrow.abi';

const POLYGON_AMOY_CHAIN_ID = 80002;
const TOKEN_DECIMALS = 18;
const DEFAULT_GAS_TOPUP_THRESHOLD = '0.005';
const DEFAULT_GAS_TOPUP_AMOUNT = '0.01';

export interface ApproveEscrowResult {
  transactionHash: string;
  blockNumber: number;
  amount: string;
}

export interface CreateReservationResult {
  reservationId: string;
  transactionHash: string;
  blockNumber: number;
}

export interface ReleaseReservationResult {
  transactionHash: string;
  blockNumber: number;
  status: 'released';
}

export interface SlashReservationResult {
  transactionHash: string;
  blockNumber: number;
  penalty: string;
  refund: string;
  status: 'slashed';
}

export interface OnChainReservation {
  reservationId: string;
  student: string;
  depositAmount: string;
  active: boolean;
  released: boolean;
  slashed: boolean;
  createdAt: number;
  releasedAt: number;
}

export type OnChainWalletTxType =
  | 'TOKEN_MINT'
  | 'ESCROW_LOCK'
  | 'ESCROW_RELEASE'
  | 'ESCROW_SLASH';

export interface OnChainWalletTransaction {
  type: OnChainWalletTxType;
  transactionHash: string | null;
  blockNumber: number | null;
  logIndex: number | null;
  timestamp: number | null;
  amount: string | null;
  amountAsset: 'CHRONOS';
  reservationId: string | null;
  penalty: string | null;
  refund: string | null;
  explorerUrl: string | null;
}

interface AlchemyTransfer {
  hash: string;
  from: string;
  to: string | null;
  value: number | null;
  blockNum: string;
  uniqueId?: string;
  metadata?: { blockTimestamp?: string };
  rawContract?: { value?: string; decimal?: string };
}

/**
 * Backend-only Polygon integration for ReservationEscrow.
 *
 * Students never talk to the chain from the mobile app. This service:
 * 1. Signs ERC-20 `approve` with the student's custodial key
 * 2. Calls create / release / slash with the admin (OPERATOR) wallet
 */
@Injectable()
export class EscrowService {
  private readonly logger = new Logger(EscrowService.name);
  private readonly provider: JsonRpcProvider;
  private readonly adminWallet: Wallet;
  private readonly adminSigner: NonceManager;
  private readonly tokenContract: Contract;
  private readonly escrowContract: Contract;
  private readonly escrowAddress: string;
  private readonly tokenAddress: string;
  private readonly gasTopupEnabled: boolean;
  private readonly gasTopupThresholdWei: bigint;
  private readonly gasTopupAmountWei: bigint;

  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
    @Inject(forwardRef(() => WalletService))
    private readonly walletService: WalletService,
  ) {
    const rpcUrl = this.requireConfig('RPC_URL');
    const privateKey = this.normalizePrivateKey(this.resolveAdminPrivateKey());
    const tokenAddress = this.requireConfig('CHRONOS_TOKEN_ADDRESS');
    const escrowAddress = this.requireConfig('ESCROW_ADDRESS');

    if (!isAddress(tokenAddress)) {
      throw new Error('CHRONOS_TOKEN_ADDRESS must be a valid EVM address');
    }
    if (!isAddress(escrowAddress)) {
      throw new Error('ESCROW_ADDRESS must be a valid EVM address');
    }

    this.tokenAddress = tokenAddress;
    this.escrowAddress = escrowAddress;
    this.provider = new JsonRpcProvider(rpcUrl, POLYGON_AMOY_CHAIN_ID);
    this.adminWallet = new Wallet(privateKey, this.provider);
    this.adminSigner = new NonceManager(this.adminWallet);

    this.gasTopupEnabled =
      (this.configService.get<string>('GAS_TOPUP_ENABLED')?.trim() || 'true') !==
      'false';
    this.gasTopupThresholdWei = parseEther(
      this.configService.get<string>('GAS_TOPUP_THRESHOLD')?.trim() ||
        DEFAULT_GAS_TOPUP_THRESHOLD,
    );
    this.gasTopupAmountWei = parseEther(
      this.configService.get<string>('GAS_TOPUP_AMOUNT')?.trim() ||
        DEFAULT_GAS_TOPUP_AMOUNT,
    );

    this.tokenContract = new Contract(
      this.tokenAddress,
      CHRONOS_TOKEN_ABI,
      this.adminSigner,
    );
    this.escrowContract = new Contract(
      this.escrowAddress,
      RESERVATION_ESCROW_ABI,
      this.adminSigner,
    );
  }

  getEscrowAddress(): string {
    return this.escrowAddress;
  }

  getTokenAddress(): string {
    return this.tokenAddress;
  }

  /**
   * Approves the escrow contract to pull `amount` CHRONOS from the student.
   * Amount is in whole CHRONOS (e.g. 20 → 20e18 wei).
   */
  async approveEscrow(
    userId: string,
    amount: number | string,
  ): Promise<ApproveEscrowResult> {
    const weiAmount = this.toWei(amount);
    if (weiAmount <= 0n) {
      throw new BadRequestException('Approval amount must be greater than zero');
    }

    const { address, signer } = await this.getStudentSigner(userId);

    // Student must pay gas for approve — top up from admin when POL is too low.
    await this.ensureStudentHasGas(address);

    const tokenAsStudent = this.tokenContract.connect(signer) as Contract;

    this.logger.log(
      `Approving escrow ${this.escrowAddress} for ${address}: ${formatUnits(weiAmount, TOKEN_DECIMALS)} CHRONOS`,
    );

    const transaction = await tokenAsStudent.approve(
      this.escrowAddress,
      weiAmount,
    );
    const receipt = await this.waitForSuccess(transaction.hash, transaction);

    return {
      transactionHash: transaction.hash,
      blockNumber: receipt.blockNumber,
      amount: formatUnits(weiAmount, TOKEN_DECIMALS),
    };
  }

  /**
   * Approves the escrow (if needed) then creates an on-chain reservation
   * using the backend OPERATOR wallet.
   */
  async createReservation(
    userId: string,
    depositAmount: number | string,
  ): Promise<CreateReservationResult> {
    const weiAmount = this.toWei(depositAmount);
    if (weiAmount <= 0n) {
      throw new BadRequestException('Deposit amount must be greater than zero');
    }

    const student = await this.requireStudentWallet(userId);

    const currentAllowance: bigint = await this.tokenContract.allowance(
      student.walletAddress,
      this.escrowAddress,
    );
    if (currentAllowance < weiAmount) {
      const approveResult = await this.approveEscrow(userId, depositAmount);
      this.logger.log(
        `Escrow approval confirmed: ${approveResult.transactionHash}`,
      );
    } else {
      this.logger.log(
        `Existing allowance (${formatUnits(currentAllowance, TOKEN_DECIMALS)}) covers deposit`,
      );
    }

    this.logger.log(
      `Creating reservation for ${student.walletAddress}: ${formatUnits(weiAmount, TOKEN_DECIMALS)} CHRONOS`,
    );

    const transaction = await this.escrowContract.createReservation(
      student.walletAddress,
      weiAmount,
    );
    const receipt = await this.waitForSuccess(transaction.hash, transaction);
    const reservationId = this.parseReservationId(receipt);

    return {
      reservationId,
      transactionHash: transaction.hash,
      blockNumber: receipt.blockNumber,
    };
  }

  /**
   * Releases the full deposit back to the student (OPERATOR only).
   */
  async releaseReservation(
    reservationId: number | string,
  ): Promise<ReleaseReservationResult> {
    const id = this.toReservationId(reservationId);

    const transaction = await this.escrowContract.releaseDeposit(id);
    const receipt = await this.waitForSuccess(transaction.hash, transaction);

    return {
      transactionHash: transaction.hash,
      blockNumber: receipt.blockNumber,
      status: 'released',
    };
  }

  /**
   * Slashes a penalty into the escrow and refunds the remainder (OPERATOR only).
   * `penalty` is in whole CHRONOS.
   */
  async slashReservation(
    reservationId: number | string,
    penalty: number | string,
  ): Promise<SlashReservationResult> {
    const id = this.toReservationId(reservationId);
    const penaltyWei = this.toWei(penalty);

    const before = await this.escrowContract.getReservation(id);
    if (!before.active) {
      throw new BadRequestException('Reservation is not active');
    }
    if (penaltyWei > before.depositAmount) {
      throw new BadRequestException('Penalty exceeds deposit amount');
    }

    const transaction = await this.escrowContract.slashDeposit(id, penaltyWei);
    const receipt = await this.waitForSuccess(transaction.hash, transaction);

    const refundWei = before.depositAmount - penaltyWei;

    return {
      transactionHash: transaction.hash,
      blockNumber: receipt.blockNumber,
      penalty: formatUnits(penaltyWei, TOKEN_DECIMALS),
      refund: formatUnits(refundWei, TOKEN_DECIMALS),
      status: 'slashed',
    };
  }

  async getReservation(
    reservationId: number | string,
  ): Promise<OnChainReservation> {
    const id = this.toReservationId(reservationId);
    const reservation = await this.escrowContract.getReservation(id);

    return {
      reservationId: reservation.reservationId.toString(),
      student: reservation.student,
      depositAmount: formatUnits(reservation.depositAmount, TOKEN_DECIMALS),
      active: reservation.active,
      released: reservation.released,
      slashed: reservation.slashed,
      createdAt: Number(reservation.createdAt),
      releasedAt: Number(reservation.releasedAt),
    };
  }

  async isReservationActive(reservationId: number | string): Promise<boolean> {
    return this.escrowContract.isReservationActive(
      this.toReservationId(reservationId),
    );
  }

  async getLockedBalance(): Promise<string> {
    const locked = await this.escrowContract.getLockedBalance();
    return formatUnits(locked, TOKEN_DECIMALS);
  }

  async getStudentBalance(userId: string): Promise<string> {
    const student = await this.requireStudentWallet(userId);
    const balance = await this.tokenContract.balanceOf(student.walletAddress);
    return formatUnits(balance, TOKEN_DECIMALS);
  }

  /**
   * Builds wallet history from Polygon Amoy:
   * - Alchemy `alchemy_getAssetTransfers` for CHRONOS transfer hashes
   * - ReservationEscrow `getReservation` / `nextReservationId` for escrow classification
   *
   * Avoids `eth_getLogs` (Alchemy free tier is limited to a 10-block window).
   * Approves and native POL gas top-ups are not included (no transfer / no event index).
   */
  async getOnChainHistory(
    studentAddress: string,
    limit = 50,
  ): Promise<OnChainWalletTransaction[]> {
    this.assertAddress(studentAddress);
    const student = studentAddress.toLowerCase();
    const escrow = this.escrowAddress.toLowerCase();

    const [outbound, inbound, reservations] = await Promise.all([
      this.getChronosTransfers({ fromAddress: studentAddress }),
      this.getChronosTransfers({ toAddress: studentAddress }),
      this.getStudentReservations(studentAddress),
    ]);

    const items: OnChainWalletTransaction[] = [];
    const usedHashes = new Set<string>();

    for (const reservation of reservations) {
      const deposit = formatUnits(reservation.depositAmount, TOKEN_DECIMALS);
      const lockTransfer = outbound.find(
        (tx) =>
          tx.to?.toLowerCase() === escrow &&
          !usedHashes.has(tx.hash) &&
          this.transferAmountMatches(tx, reservation.depositAmount),
      );
      if (lockTransfer) {
        usedHashes.add(lockTransfer.hash);
      }

      items.push(
        this.fromTransferOrReservation({
          type: 'ESCROW_LOCK',
          transfer: lockTransfer,
          amount: deposit,
          reservationId: reservation.reservationId.toString(),
          fallbackTimestamp: Number(reservation.createdAt),
        }),
      );

      if (reservation.released) {
        const releaseTransfer = inbound.find(
          (tx) =>
            tx.from.toLowerCase() === escrow &&
            !usedHashes.has(tx.hash) &&
            this.transferAmountMatches(tx, reservation.depositAmount),
        );
        if (releaseTransfer) {
          usedHashes.add(releaseTransfer.hash);
        }
        items.push(
          this.fromTransferOrReservation({
            type: 'ESCROW_RELEASE',
            transfer: releaseTransfer,
            amount: deposit,
            reservationId: reservation.reservationId.toString(),
            fallbackTimestamp: Number(reservation.releasedAt) || null,
          }),
        );
      }

      if (reservation.slashed) {
        const slashTransfer = inbound.find(
          (tx) =>
            tx.from.toLowerCase() === escrow && !usedHashes.has(tx.hash),
        );
        if (slashTransfer) {
          usedHashes.add(slashTransfer.hash);
        }
        const refundAmount = slashTransfer
          ? this.formatTransferAmount(slashTransfer)
          : null;
        let penaltyAmount = deposit;
        if (refundAmount !== null) {
          try {
            penaltyAmount = formatUnits(
              reservation.depositAmount -
                parseUnits(refundAmount, TOKEN_DECIMALS),
              TOKEN_DECIMALS,
            );
          } catch {
            penaltyAmount = deposit;
          }
        }
        items.push(
          this.fromTransferOrReservation({
            type: 'ESCROW_SLASH',
            transfer: slashTransfer,
            amount: penaltyAmount,
            reservationId: reservation.reservationId.toString(),
            penalty: penaltyAmount,
            refund: refundAmount,
            fallbackTimestamp: Number(reservation.releasedAt) || null,
          }),
        );
      }
    }

    for (const transfer of inbound) {
      if (usedHashes.has(transfer.hash)) {
        continue;
      }
      if (transfer.from.toLowerCase() === escrow) {
        continue;
      }
      // Initial mint (or other inbound CHRONOS not from escrow).
      items.push(
        this.fromTransferOrReservation({
          type: 'TOKEN_MINT',
          transfer,
          amount: this.formatTransferAmount(transfer),
          reservationId: null,
          fallbackTimestamp: null,
        }),
      );
      usedHashes.add(transfer.hash);
    }

    items.sort((a, b) => {
      const timeA = a.timestamp ?? 0;
      const timeB = b.timestamp ?? 0;
      if (timeA !== timeB) {
        return timeB - timeA;
      }
      const blockA = a.blockNumber ?? 0;
      const blockB = b.blockNumber ?? 0;
      return blockB - blockA;
    });

    return items.slice(0, Math.max(1, Math.min(limit, 100)));
  }

  private async getStudentReservations(studentAddress: string) {
    const nextId: bigint = await this.escrowContract.nextReservationId();
    const student = studentAddress.toLowerCase();
    const reservations: Array<{
      reservationId: bigint;
      student: string;
      depositAmount: bigint;
      active: boolean;
      released: boolean;
      slashed: boolean;
      createdAt: bigint;
      releasedAt: bigint;
    }> = [];

    for (let id = 1n; id < nextId; id++) {
      const reservation = await this.escrowContract.getReservation(id);
      if (
        reservation.student &&
        reservation.student.toLowerCase() === student &&
        reservation.reservationId !== 0n
      ) {
        reservations.push({
          reservationId: reservation.reservationId,
          student: reservation.student,
          depositAmount: reservation.depositAmount,
          active: reservation.active,
          released: reservation.released,
          slashed: reservation.slashed,
          createdAt: reservation.createdAt,
          releasedAt: reservation.releasedAt,
        });
      }
    }

    return reservations;
  }

  private async getChronosTransfers(params: {
    fromAddress?: string;
    toAddress?: string;
  }): Promise<AlchemyTransfer[]> {
    const transfers: AlchemyTransfer[] = [];
    let pageKey: string | undefined;

    do {
      const payload: Record<string, unknown> = {
        fromBlock: '0x0',
        toBlock: 'latest',
        contractAddresses: [this.tokenAddress],
        category: ['erc20'],
        withMetadata: true,
        excludeZeroValue: false,
        maxCount: '0x3e8',
        order: 'asc',
      };
      if (params.fromAddress) {
        payload.fromAddress = params.fromAddress;
      }
      if (params.toAddress) {
        payload.toAddress = params.toAddress;
      }
      if (pageKey) {
        payload.pageKey = pageKey;
      }

      const response = (await this.provider.send('alchemy_getAssetTransfers', [
        payload,
      ])) as {
        transfers?: AlchemyTransfer[];
        pageKey?: string;
      };

      transfers.push(...(response.transfers ?? []));
      pageKey = response.pageKey;
    } while (pageKey);

    return transfers;
  }

  private transferAmountMatches(
    transfer: AlchemyTransfer,
    expectedWei: bigint,
  ): boolean {
    const raw = transfer.rawContract?.value;
    if (raw) {
      try {
        return BigInt(raw) === expectedWei;
      } catch {
        // fall through to float compare
      }
    }
    if (transfer.value == null) {
      return false;
    }
    try {
      return parseUnits(String(transfer.value), TOKEN_DECIMALS) === expectedWei;
    } catch {
      return false;
    }
  }

  private formatTransferAmount(transfer: AlchemyTransfer): string {
    const raw = transfer.rawContract?.value;
    if (raw) {
      try {
        return formatUnits(BigInt(raw), TOKEN_DECIMALS);
      } catch {
        // fall through
      }
    }
    return transfer.value != null ? String(transfer.value) : '0';
  }

  private fromTransferOrReservation(input: {
    type: OnChainWalletTxType;
    transfer?: AlchemyTransfer;
    amount: string | null;
    reservationId: string | null;
    penalty?: string | null;
    refund?: string | null;
    fallbackTimestamp: number | null;
  }): OnChainWalletTransaction {
    const hash = input.transfer?.hash ?? null;
    const blockNumber = input.transfer?.blockNum
      ? Number.parseInt(input.transfer.blockNum, 16)
      : null;
    const timestampFromMeta = input.transfer?.metadata?.blockTimestamp
      ? Math.floor(
          new Date(input.transfer.metadata.blockTimestamp).getTime() / 1000,
        )
      : null;

    return {
      type: input.type,
      transactionHash: hash,
      blockNumber,
      logIndex: null,
      timestamp: timestampFromMeta ?? input.fallbackTimestamp,
      amount: input.amount,
      amountAsset: 'CHRONOS',
      reservationId: input.reservationId,
      penalty: input.penalty ?? null,
      refund: input.refund ?? null,
      explorerUrl: hash ? `https://amoy.polygonscan.com/tx/${hash}` : null,
    };
  }

  /**
   * If the student wallet has less POL than the threshold, the admin sends
   * a fixed top-up so the student can pay gas for `approve`.
   */
  async ensureStudentHasGas(
    studentAddress: string,
  ): Promise<{ toppedUp: boolean; transactionHash: string | null }> {
    if (!this.gasTopupEnabled) {
      return { toppedUp: false, transactionHash: null };
    }

    this.assertAddress(studentAddress);

    const studentBalance = await this.provider.getBalance(studentAddress);
    if (studentBalance >= this.gasTopupThresholdWei) {
      this.logger.log(
        `Student ${studentAddress} has ${formatEther(studentBalance)} POL (threshold ${formatEther(this.gasTopupThresholdWei)}) — no top-up`,
      );
      return { toppedUp: false, transactionHash: null };
    }

    const adminBalance = await this.provider.getBalance(this.adminWallet.address);
    const estimatedTopupCost = this.gasTopupAmountWei + parseEther('0.002');
    if (adminBalance < estimatedTopupCost) {
      throw new Error(
        `Admin wallet ${this.adminWallet.address} has insufficient POL to fund student gas ` +
          `(balance ${formatEther(adminBalance)}, need ~${formatEther(estimatedTopupCost)})`,
      );
    }

    this.logger.log(
      `Student ${studentAddress} has ${formatEther(studentBalance)} POL — admin topping up ${formatEther(this.gasTopupAmountWei)} POL`,
    );

    const transaction = await this.adminSigner.sendTransaction({
      to: studentAddress,
      value: this.gasTopupAmountWei,
      maxPriorityFeePerGas: parseUnits('25', 'gwei'),
      maxFeePerGas: parseUnits('27', 'gwei'),
    });
    const receipt = await transaction.wait();
    if (!receipt || receipt.status !== 1) {
      throw new Error(`Gas top-up failed on Polygon: ${transaction.hash}`);
    }

    this.logger.log(
      `Gas top-up sent to ${studentAddress}: ${transaction.hash}`,
    );

    return { toppedUp: true, transactionHash: transaction.hash };
  }

  private assertAddress(value: string): void {
    if (!isAddress(value)) {
      throw new Error('Wallet address must be a valid EVM address');
    }
  }

  private async getStudentSigner(userId: string): Promise<{
    address: string;
    signer: Wallet;
  }> {
    const student = await this.requireStudentWallet(userId);

    if (!student.encryptedPrivateKey) {
      throw new NotFoundException('Student custodial key is missing');
    }

    const privateKey = this.walletService.decryptPrivateKey(
      student.encryptedPrivateKey,
    );
    const signer = new Wallet(privateKey, this.provider);

    if (signer.address.toLowerCase() !== student.walletAddress.toLowerCase()) {
      throw new Error(
        'Decrypted key does not match the stored student wallet address',
      );
    }

    return { address: student.walletAddress, signer };
  }

  private async requireStudentWallet(userId: string): Promise<{
    walletAddress: string;
    encryptedPrivateKey: string | null;
  }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        walletAddress: true,
        encryptedPrivateKey: true,
        role: true,
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }
    if (!user.walletAddress) {
      throw new NotFoundException('Student wallet has not been provisioned');
    }

    return {
      walletAddress: user.walletAddress,
      encryptedPrivateKey: user.encryptedPrivateKey,
    };
  }

  private parseReservationId(receipt: ContractTransactionReceipt): string {
    for (const log of receipt.logs) {
      try {
        const parsed = this.escrowContract.interface.parseLog({
          topics: [...log.topics],
          data: log.data,
        });
        if (parsed?.name === 'ReservationCreated') {
          return parsed.args.reservationId.toString();
        }
      } catch {
        // Ignore logs from other contracts (e.g. ERC-20 Transfer).
      }
    }

    throw new Error(
      'ReservationCreated event not found in createReservation receipt',
    );
  }

  private async waitForSuccess(
    hash: string,
    transaction: { wait: () => Promise<ContractTransactionReceipt | null> },
  ): Promise<ContractTransactionReceipt> {
    const receipt = await transaction.wait();
    if (!receipt || receipt.status !== 1) {
      throw new Error(`Transaction failed on Polygon: ${hash}`);
    }
    return receipt;
  }

  private toWei(amount: number | string): bigint {
    const normalized =
      typeof amount === 'number' ? amount.toString() : amount.trim();
    if (!normalized || Number.isNaN(Number(normalized))) {
      throw new BadRequestException('Invalid token amount');
    }
    return parseUnits(normalized, TOKEN_DECIMALS);
  }

  private toReservationId(reservationId: number | string): bigint {
    try {
      return BigInt(reservationId);
    } catch {
      throw new BadRequestException('Invalid reservation id');
    }
  }

  private resolveAdminPrivateKey(): string {
    return (
      this.configService.get<string>('ADMIN_PRIVATE_KEY')?.trim() ||
      this.configService.get<string>('PRIVATE_KEY')?.trim() ||
      ''
    );
  }

  private requireConfig(name: string): string {
    const value = this.configService.get<string>(name)?.trim();
    if (!value) {
      throw new Error(`${name} is required`);
    }
    return value;
  }

  private normalizePrivateKey(value: string): string {
    if (!value) {
      throw new Error(
        'ADMIN_PRIVATE_KEY (or PRIVATE_KEY) is required for escrow operations',
      );
    }
    const normalized = value.startsWith('0x') ? value.slice(2) : value;
    if (!/^[0-9a-fA-F]{64}$/.test(normalized)) {
      throw new Error(
        'ADMIN_PRIVATE_KEY must be exactly 64 hexadecimal characters',
      );
    }
    return `0x${normalized}`;
  }
}
