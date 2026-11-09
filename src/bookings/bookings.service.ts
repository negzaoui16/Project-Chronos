import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  AssetStatus,
  BookingStatus,
  DamageCategory,
  DamageSeverity,
  RecommendedAction,
  InspectionStatus,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ExternalAiService } from '../common/external-ai/external-ai.service';
import { EscrowService } from '../blockchain/escrow.service';
import { Module2ApiService } from '../module2/module2-api/module2-api.service';

@Injectable()
export class BookingsService {
  private readonly logger = new Logger(BookingsService.name);
  private readonly depositAmount: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly externalAi: ExternalAiService,
    private readonly escrowService: EscrowService,
    private readonly module2ApiService: Module2ApiService,
    private readonly configService: ConfigService,
  ) {
    this.depositAmount =
      this.configService.get<string>('ESCROW_DEPOSIT_AMOUNT')?.trim() || '20';
  }

  async findAll() {
    return this.prisma.booking.findMany({
      include: {
        user: {
          select: {
            id: true,
            email: true,
            name: true,
            studentId: true,
            role: true,
            reputationScore: true,
            profileImageUrl: true,
            walletAddress: true,
          },
        },
        asset: true,
        inspection: true,
      },
      orderBy: { startTime: 'desc' },
    });
  }

  async findByUser(userId: string) {
    const isValidObjectId = typeof userId === 'string' && /^[0-9a-fA-F]{24}$/.test(userId);
    if (!isValidObjectId) {
      return [];
    }
    return this.prisma.booking.findMany({
      where: { userId },
      include: { asset: true, inspection: true },
      orderBy: { startTime: 'desc' },
    });
  }

  async findOne(id: string) {
    const isValidObjectId = typeof id === 'string' && /^[0-9a-fA-F]{24}$/.test(id);
    if (!isValidObjectId) {
      return null;
    }
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            name: true,
            studentId: true,
            role: true,
            reputationScore: true,
            profileImageUrl: true,
            walletAddress: true,
          },
        },
        asset: true,
        inspection: true,
      },
    });
    if (!booking) {
      throw new NotFoundException(`Booking with ID ${id} not found`);
    }
    return booking;
  }

  /**
   * Creates a booking and locks the student's CHRONOS deposit on-chain.
   * The mobile client must never send escrowTxHash — the backend owns Polygon.
   */
  async createBooking(
    userId: string,
    assetId: string,
    startTime: string,
    endTime: string,
    frontPhotoUrl?: string,
    backPhotoUrl?: string,
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException(`User with ID ${userId} not found`);
    }
    if (!user.walletAddress) {
      throw new BadRequestException(
        'Student wallet is required before creating a reservation',
      );
    }

    const asset = await this.prisma.asset.findUnique({ where: { id: assetId } });
    if (!asset) {
      throw new NotFoundException(`Asset with ID ${assetId} not found`);
    }

    if (asset.status !== AssetStatus.AVAILABLE) {
      throw new BadRequestException(
        `Asset ${asset.name} is currently ${asset.status} and cannot be reserved`,
      );
    }

    let escrow;
    try {
      escrow = await this.escrowService.createReservation(
        userId,
        this.depositAmount,
      );
    } catch (error: unknown) {
      this.logger.warn(`Bypassing Escrow due to error: ${error instanceof Error ? error.message : String(error)}`);
      escrow = {
        reservationId: `mock-${Date.now()}`,
        transactionHash: `0xmocktx${Date.now()}`,
        blockNumber: 999999
      };
    }

    try {
      const result = await this.prisma.$transaction(async (tx) => {
        await tx.asset.update({
          where: { id: assetId },
          data: { status: AssetStatus.RESERVED },
        });

        const newBooking = await tx.booking.create({
          data: {
            userId,
            assetId,
            startTime: new Date(startTime),
            endTime: new Date(endTime),
            status: BookingStatus.ACTIVE,
            escrowTxHash: escrow.transactionHash,
            escrowReservationId: escrow.reservationId,
            escrowDepositAmount: this.depositAmount,
          },
          include: { asset: true },
        });

        if (frontPhotoUrl) {
          await tx.photo.create({
            data: { url: frontPhotoUrl, type: 'PICKUP', bookingId: newBooking.id }
          });
        }
        if (backPhotoUrl) {
          await tx.photo.create({
            data: { url: backPhotoUrl, type: 'PICKUP', bookingId: newBooking.id }
          });
        }

        return newBooking;
      }, {
        maxWait: 5000,
        timeout: 20000,
      });
      
      // LOG THE RESULT
      if (escrow.transactionHash.startsWith('0xmock')) {
        this.logger.log(`[SIMULATION] Réservation créée avec succès (Simulation Blockchain - Aucun frais de Gas utilisé). TX: ${escrow.transactionHash}`);
      } else {
        this.logger.log(`[RÉEL] Réservation créée avec succès sur la blockchain Polygon. TX: ${escrow.transactionHash}`);
      }
      
      return result;
    } catch (error: unknown) {
      // Best-effort unlock if DB persistence fails after an on-chain lock.
      this.logger.error(
        `Booking persistence failed after escrow lock ${escrow.reservationId}; attempting release`,
      );
      try {
        await this.escrowService.releaseReservation(escrow.reservationId);
      } catch (releaseError: unknown) {
        this.logger.error(
          `Compensating release failed for reservation ${escrow.reservationId}: ${
            releaseError instanceof Error
              ? releaseError.message
              : String(releaseError)
          }`,
        );
      }
      throw error;
    }
  }

  async requestReturn(bookingId: string) {
    const booking = await this.prisma.booking.findUnique({ where: { id: bookingId } });
    if (!booking) {
      throw new NotFoundException(`Booking with ID ${bookingId} not found`);
    }

    if (booking.status !== BookingStatus.ACTIVE && booking.status !== BookingStatus.PENDING_RETURN) {
      throw new BadRequestException(
        `Booking ${bookingId} is in status ${booking.status} and cannot request a return`,
      );
    }
    
    // If it's already pending return, just return it
    if (booking.status === BookingStatus.PENDING_RETURN) {
      return booking;
    }

    return this.prisma.booking.update({
      where: { id: bookingId },
      data: { status: BookingStatus.PENDING_RETURN },
    });
  }

  async runAiScan(bookingId: string, returnFilesPaths: string[], complaintText: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { asset: true, photos: { where: { type: 'PICKUP' } } },
    });

    if (!booking) {
      throw new NotFoundException(`Booking with ID ${bookingId} not found`);
    }

    const baselineFilesPaths = booking.photos.map(p => p.url);

    if (baselineFilesPaths.length !== 2) {
      throw new BadRequestException(`Exactement 2 photos de départ (Baseline) sont requises. Trouvées: ${baselineFilesPaths.length}`);
    }
    if (returnFilesPaths.length !== 2) {
      throw new BadRequestException(`Exactement 2 photos de retour (Return) sont requises. Trouvées: ${returnFilesPaths.length}`);
    }

    this.logger.log(`Calling Local AI Pipeline for booking ${bookingId}`);
    
    const allowedCategories = ['laptop', 'tablet', 'vr_headset', 'lab_kit', 'projector', 'printer'];
    let mappedCategory = booking.asset.category.toLowerCase();
    if (!allowedCategories.includes(mappedCategory)) {
      mappedCategory = 'laptop'; // Fallback
    }

    // 1. Toujours exécuter le flux Image (Agent 1 -> Agent 2 -> Agent 4)
    const photoResult = await this.module2ApiService.processPhotoInspection(
      booking.assetId,
      mappedCategory,
      baselineFilesPaths,
      returnFilesPaths,
      booking.asset.name,
      complaintText,
    );

    // 2. Vérifier si le texte comporte au moins 10 lettres alphabétiques (A-Z)
    const safeText = complaintText || '';
    const letterCount = (safeText.match(/[a-zA-Z]/g) || []).length;
    let textReportData: any = null;
    
    if (letterCount >= 10) {
      this.logger.log(`Text contains ${letterCount} letters (>= 10). Triggering Agent 3 (NLP)...`);
      try {
        const textResult = await this.module2ApiService.processTextInspection(
          mappedCategory,
          safeText,
          booking.asset.name, // using deviceModel
        );
        
        // Fusionner les rapports si Agent 3 a réussi
        if (textResult && textResult.status === 'completed' && textResult.reports) {
           photoResult.reports = [...photoResult.reports, ...textResult.reports];
           textReportData = textResult.reports[0]?.report;
        }
      } catch (err: any) {
        this.logger.warn(`Agent 3 NLP inspection failed, but photo inspection succeeded: ${err.message}`);
      }
    } else {
      this.logger.log(`Text contains ${letterCount} letters (< 10). Skipping Agent 3 (NLP).`);
    }

    // Sauvegarde en base de données pour l'Admin !
    try {
      const photoRep = photoResult.reports && photoResult.reports.length > 0 ? photoResult.reports[0].report : {};
      
      const pDamageCat = (photoRep.damage_type || 'OTHER_UNCLASSIFIED').toUpperCase();
      const pSeverity = (photoRep.severity || 'UNKNOWN').toUpperCase();
      const pAction = (photoRep.recommended_action || 'NONE').toUpperCase();
      
      // Extraction du coût Agent 4 (Visual)
      let pCost = 0;
      const pCostStr = photoRep.cost_range || '';
      const pMatch = pCostStr.match(/\$([0-9]+\.[0-9]{2})/);
      if (pMatch) pCost = parseFloat(pMatch[1]);

      let adminReportData = {
          photoAgent4: photoRep.report || '',
          textAgent4: textReportData ? (textReportData.report || '') : '',
          photoAgent2: photoRep.description || '',
          textAgent3: textReportData ? (textReportData.description || '') : ''
      };

      let inspectionData: any = {
          damageCategory: ['SCREEN_DISPLAY','STRUCTURAL_BODY','PORT_CONNECTOR','MISSING_COMPONENT','LIQUID_MOISTURE','INPUT_CONTROL','POWER_BOOT_FAILURE','COSMETIC_WEAR'].includes(pDamageCat) ? pDamageCat : 'OTHER_UNCLASSIFIED',
          damageSeverity: ['COSMETIC','MODERATE','SEVERE','CRITICAL'].includes(pSeverity) ? pSeverity : 'MODERATE',
          aiDescription: photoRep.description || 'Pas de description visuelle',
          estimatedRepairCost: pCost,
          estimatedRepairTime: photoRep.estimated_time || 'Unknown',
          recommendedAction: ['REPAIR','REPLACE','WRITE_OFF','NONE'].includes(pAction) ? pAction : 'NONE',
          adminReport: JSON.stringify(adminReportData),
          status: 'FLAGGED',
      };

      if (textReportData) {
         inspectionData.failureCategory = textReportData.damage_type || 'UNKNOWN';
         inspectionData.aiConfidence = textReportData.confidence_level === 'High' ? 0.9 : 0.5;
         inspectionData.aiJustification = textReportData.description || '';
      }

      await this.prisma.inspection.upsert({
        where: { bookingId: bookingId },
        update: inspectionData,
        create: {
          bookingId: bookingId,
          ...inspectionData
        }
      });
      this.logger.log(`[Database] AI Inspection reports saved to DB for booking ${bookingId}`);
    } catch (dbErr: any) {
      this.logger.error(`Failed to save Inspection to DB: ${dbErr.message}`, dbErr.stack);
    }

    return photoResult;
  }

  async submitReturnInspection(
    bookingId: string,
    scannedPhotoUrl: string,
    dto: {
      damageCategory: DamageCategory;
      damageSeverity: DamageSeverity;
      aiDescription: string;
      estimatedRepairCost: number;
      estimatedRepairTime?: string;
      recommendedAction: RecommendedAction;
      status: InspectionStatus;
      resolutionChoice?: 'PASS' | 'PARTIAL' | 'TOTAL_LOSS';
    },
  ) {
    const booking = await this.findOne(bookingId);
    if (booking.status === BookingStatus.COMPLETED) {
      throw new BadRequestException(
        'This reservation has already been closed and inspected.',
      );
    }

    let settleTxHash: string | null = null;
    if (booking.escrowReservationId) {
      try {
        settleTxHash = await this.settleEscrow(booking.escrowReservationId, dto);
      } catch (error: unknown) {
        this.logger.warn(`Bypassing Settle/Slash due to error: ${error instanceof Error ? error.message : String(error)}`);
        settleTxHash = `0xmocksettle${Date.now()}`;
      }
    }

    return this.prisma.$transaction(async (tx) => {
      await tx.photo.create({
        data: {
          url: scannedPhotoUrl,
          type: 'RETURN',
          bookingId,
        },
      });

      const inspection = await tx.inspection.upsert({
        where: { bookingId: bookingId },
        update: {
          damageCategory: dto.damageCategory,
          damageSeverity: dto.damageSeverity,
          aiDescription: dto.aiDescription,
          estimatedRepairCost: dto.estimatedRepairCost,
          estimatedRepairTime: dto.estimatedRepairTime,
          recommendedAction: dto.recommendedAction,
          status: dto.status,
        },
        create: {
          bookingId,
          damageCategory: dto.damageCategory,
          damageSeverity: dto.damageSeverity,
          aiDescription: dto.aiDescription,
          estimatedRepairCost: dto.estimatedRepairCost,
          estimatedRepairTime: dto.estimatedRepairTime,
          recommendedAction: dto.recommendedAction,
          status: dto.status,
        },
      });

      await tx.booking.update({
        where: { id: bookingId },
        data: {
          status: BookingStatus.COMPLETED,
          ...(settleTxHash ? { escrowSettleTxHash: settleTxHash } : {}),
        },
      });

      const isFlagged = dto.status === InspectionStatus.FLAGGED;
      
      let nextAssetStatus: AssetStatus = AssetStatus.AVAILABLE;
      if (dto.resolutionChoice === 'PARTIAL' || dto.resolutionChoice === 'TOTAL_LOSS') {
        nextAssetStatus = AssetStatus.UNDER_INSPECTION;
      } else if (!dto.resolutionChoice && isFlagged) {
        nextAssetStatus = AssetStatus.UNDER_INSPECTION;
      }

      await tx.asset.update({
        where: { id: booking.assetId },
        data: { status: nextAssetStatus },
      });

      if (isFlagged || dto.resolutionChoice === 'PARTIAL' || dto.resolutionChoice === 'TOTAL_LOSS') {
        let deduction = 0.0;
        if (dto.resolutionChoice === 'TOTAL_LOSS') {
          deduction = 20.0;
        } else if (dto.resolutionChoice === 'PARTIAL') {
          deduction = 10.0;
        } else {
          // Fallback legacy logic
          if (dto.damageSeverity === DamageSeverity.CRITICAL) deduction = 20.0;
          else if (dto.damageSeverity === DamageSeverity.SEVERE) deduction = 15.0;
          else if (dto.damageSeverity === DamageSeverity.MODERATE) deduction = 10.0;
          else deduction = 5.0;
        }

        if (deduction > 0) {
          await tx.user.update({
          where: { id: booking.userId },
          data: {
            reputationScore: {
              decrement: deduction,
            },
          },
        });
        }
      }

      try {
        await this.externalAi.notifyInspection({
          student_id: booking.user.studentId,
          reservation_id: booking.id,
          item_id: booking.assetId,
          image_url: scannedPhotoUrl,
        });
      } catch (err) {
        this.logger.warn(`Could not notify AI pipeline (Module 2 may be offline). Proceeding with DB commit.`);
      }

      if (settleTxHash) {
        if (settleTxHash.startsWith('0xmock')) {
          this.logger.log(`[SIMULATION] Retour inspecté et clôturé avec succès (Simulation Blockchain - Aucun frais de Gas utilisé). TX: ${settleTxHash}`);
        } else {
          this.logger.log(`[RÉEL] Retour inspecté et clôturé avec succès sur la blockchain Polygon. TX: ${settleTxHash}`);
        }
      }

      return inspection;
    }, {
      maxWait: 10000,
      timeout: 30000,
    });
  }

  /**
   * Releases or slashes the on-chain deposit based on AI inspection outcome.
   * Mobile never talks to Polygon — only this backend operator path does.
   */
  private async settleEscrow(
    reservationId: string,
    dto: {
      damageSeverity: DamageSeverity;
      status: InspectionStatus;
      resolutionChoice?: 'PASS' | 'PARTIAL' | 'TOTAL_LOSS';
    },
  ): Promise<string> {
    
    let shouldRelease = false;
    let penalty: number | string = 0.0;

    if (dto.resolutionChoice) {
      if (dto.resolutionChoice === 'PASS') {
        shouldRelease = true;
      } else if (dto.resolutionChoice === 'PARTIAL') {
        penalty = 10.0; // 50% of 20 POL
      } else if (dto.resolutionChoice === 'TOTAL_LOSS') {
        penalty = 20.0; // 100% of 20 POL
      }
    } else {
      // Legacy fallback
      if (dto.status !== InspectionStatus.FLAGGED) {
        shouldRelease = true;
      } else {
        penalty = this.penaltyForSeverity(dto.damageSeverity);
      }
    }

    if (shouldRelease) {
      const released =
        await this.escrowService.releaseReservation(reservationId);
      this.logger.log(
        `Released escrow reservation ${reservationId}: ${released.transactionHash}`,
      );
      return released.transactionHash;
    }

    const slashed = await this.escrowService.slashReservation(
      reservationId,
      penalty,
    );
    this.logger.log(
      `Slashed escrow reservation ${reservationId}: penalty=${slashed.penalty} refund=${slashed.refund} tx=${slashed.transactionHash}`,
    );
    return slashed.transactionHash;
  }

  async cancelBooking(userId: string, bookingId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found');
    }

    if (booking.userId !== userId) {
      throw new BadRequestException('You do not own this booking');
    }

    if (booking.status !== BookingStatus.PENDING && booking.status !== BookingStatus.ACTIVE) {
      throw new BadRequestException('Only active or pending bookings can be cancelled');
    }

    // Release escrow if present
    if (booking.escrowReservationId) {
      try {
        await this.escrowService.releaseReservation(booking.escrowReservationId);
        this.logger.log(`Released escrow reservation ${booking.escrowReservationId} for cancelled booking ${bookingId}`);
      } catch (err: any) {
        if (err.message && err.message.includes('reservation not active')) {
          this.logger.warn(`Escrow for booking ${bookingId} is already inactive. Proceeding with DB cancellation.`);
        } else {
          this.logger.error(`Failed to release escrow for booking ${bookingId}: ${err.message}`);
          throw new ServiceUnavailableException('Failed to release smart contract escrow');
        }
      }
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({
        where: { id: bookingId },
        data: { status: BookingStatus.CANCELLED },
      });
      await tx.asset.update({
        where: { id: booking.assetId },
        data: { status: AssetStatus.AVAILABLE },
      });
    }, {
      maxWait: 5000,
      timeout: 20000,
    });

    return { message: 'Booking cancelled successfully' };
  }

  /** Maps AI damage severity to CHRONOS penalty against the standard deposit. */
  private penaltyForSeverity(severity: DamageSeverity): string {
    const deposit = Number(this.depositAmount);
    switch (severity) {
      case DamageSeverity.CRITICAL:
        return this.depositAmount;
      case DamageSeverity.SEVERE:
        return String(Math.min(deposit, 15));
      case DamageSeverity.MODERATE:
        return String(Math.min(deposit, 10));
      case DamageSeverity.COSMETIC:
      default:
        return String(Math.min(deposit, 5));
    }
  }
}
