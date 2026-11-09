import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  Contract,
  ContractTransactionResponse,
  JsonRpcProvider,
  NonceManager,
  Wallet,
  formatUnits,
  isAddress,
} from 'ethers';
import { CHRONOS_TOKEN_ABI } from './chronos-token.abi';

const POLYGON_AMOY_CHAIN_ID = 80002;

export interface MintInitialTokensResult {
  transactionHash: string | null;
  blockNumber: number | null;
  success: boolean;
  alreadyMinted: boolean;
}

/**
 * Carries whether a mint transaction was broadcast before an error occurred.
 * Registration uses this to avoid deleting a wallet whose transaction may
 * still be confirmed by Polygon.
 */
export class MintInitialTokensError extends Error {
  constructor(
    message: string,
    public readonly transactionHash: string | null,
    public readonly submitted: boolean,
  ) {
    super(message);
    this.name = MintInitialTokensError.name;
  }
}

@Injectable()
export class BlockchainService {
  private readonly logger = new Logger(BlockchainService.name);
  private readonly provider: JsonRpcProvider;
  private readonly adminWallet: Wallet;
  private readonly tokenContract: Contract;
  private readonly tokenAddress: string;

  constructor(private readonly configService: ConfigService) {
    const rpcUrl = this.requireConfig('RPC_URL');
    const privateKey = this.normalizePrivateKey(
      this.requireConfig('ADMIN_PRIVATE_KEY'),
    );
    const tokenAddress = this.requireConfig('CHRONOS_TOKEN_ADDRESS');

    if (!isAddress(tokenAddress)) {
      throw new Error('CHRONOS_TOKEN_ADDRESS must be a valid EVM address');
    }

    this.tokenAddress = tokenAddress;
    this.provider = new JsonRpcProvider(rpcUrl, POLYGON_AMOY_CHAIN_ID);
    this.adminWallet = new Wallet(privateKey, this.provider);
    const adminSigner = new NonceManager(this.adminWallet);
    this.tokenContract = new Contract(
      this.tokenAddress,
      CHRONOS_TOKEN_ABI,
      adminSigner,
    );
  }

  /**
   * Calls ChronosToken.mintStudent and waits for Polygon confirmation.
   */
  async mintInitialTokens(
    walletAddress: string,
  ): Promise<MintInitialTokensResult> {
    this.assertAddress(walletAddress);

    let transaction: ContractTransactionResponse | undefined;

    try {
      const alreadyMinted =
        await this.tokenContract.hasReceivedInitialTokens(walletAddress);

      if (alreadyMinted) {
        return {
          transactionHash: null,
          blockNumber: null,
          success: true,
          alreadyMinted: true,
        };
      }

      const adminCanMint = await this.tokenContract.hasMinterRole(
        this.adminWallet.address,
      );
      if (!adminCanMint) {
        throw new Error(
          `Backend admin ${this.adminWallet.address} does not have MINTER_ROLE`,
        );
      }

      transaction = await this.tokenContract.mintStudent(walletAddress);
      this.logger.log(
        `Submitted initial token mint for ${walletAddress}: ${transaction.hash}`,
      );

      const receipt = await transaction.wait();
      if (!receipt || receipt.status !== 1) {
        throw new Error('Polygon did not confirm a successful mint');
      }

      return {
        transactionHash: transaction.hash,
        blockNumber: receipt.blockNumber,
        success: true,
        alreadyMinted: false,
      };
    } catch (error: unknown) {
      throw new MintInitialTokensError(
        this.errorMessage(error),
        transaction?.hash ?? null,
        transaction !== undefined,
      );
    }
  }

  /**
   * Returns CHRONOS balance as a decimal string to avoid JS number precision
   * loss (for example, "100.0").
   */
  async getBalance(walletAddress: string): Promise<string> {
    this.assertAddress(walletAddress);

    const [balance, decimals] = await Promise.all([
      this.tokenContract.balanceOf(walletAddress),
      this.tokenContract.decimals(),
    ]);

    return formatUnits(balance, decimals);
  }

  async hasReceivedInitialTokens(walletAddress: string): Promise<boolean> {
    this.assertAddress(walletAddress);
    return this.tokenContract.hasReceivedInitialTokens(walletAddress);
  }

  getContractAddress(): string {
    return this.tokenAddress;
  }

  private requireConfig(name: string): string {
    const value = this.configService.get<string>(name)?.trim();
    if (!value) {
      throw new Error(`${name} is required`);
    }
    return value;
  }

  private normalizePrivateKey(value: string): string {
    const normalized = value.startsWith('0x') ? value.slice(2) : value;
    if (!/^[0-9a-fA-F]{64}$/.test(normalized)) {
      throw new Error(
        'ADMIN_PRIVATE_KEY must be exactly 64 hexadecimal characters',
      );
    }
    return `0x${normalized}`;
  }

  private assertAddress(value: string): void {
    if (!isAddress(value)) {
      throw new Error('Wallet address must be a valid EVM address');
    }
  }

  private errorMessage(error: unknown): string {
    return error instanceof Error ? error.message : String(error);
  }
}
