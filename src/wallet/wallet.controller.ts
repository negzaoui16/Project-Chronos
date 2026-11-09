import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { WalletService } from './wallet.service';

interface AuthenticatedRequest {
  user: {
    id: string;
  };
}

@Controller('wallet')
@UseGuards(JwtAuthGuard)
export class WalletController {
  constructor(private readonly walletService: WalletService) {}

  /**
   * Returns wallet metadata and the live Polygon Amoy CHRONOS balance for the
   * currently authenticated user.
   */
  @Get('me')
  getMyWallet(@Req() request: AuthenticatedRequest) {
    return this.walletService.getWalletOverview(request.user.id);
  }

  /**
   * Returns on-chain mint / approve / escrow history for the authenticated
   * student by querying Polygon Amoy events (not a database ledger).
   */
  @Get('me/transactions')
  getMyTransactions(
    @Req() request: AuthenticatedRequest,
    @Query('limit') limit?: string,
  ) {
    const parsed = limit ? Number.parseInt(limit, 10) : 50;
    const safeLimit = Number.isFinite(parsed) ? parsed : 50;
    return this.walletService.getTransactionHistory(
      request.user.id,
      safeLimit,
    );
  }
}
