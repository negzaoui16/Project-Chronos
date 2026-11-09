import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';

export interface OutboundInspectionPayload {
  student_id: string;
  reservation_id: string;
  item_id: string;
  image_url: string;
}

@Injectable()
export class ExternalAiService {
  private readonly logger = new Logger(ExternalAiService.name);

  constructor(private readonly httpService: HttpService) {}

  async notifyInspection(payload: OutboundInspectionPayload): Promise<any> {
    const fastApiUrl = process.env.FASTAPI_URL || 'http://localhost:8000';
    const endpoint = `${fastApiUrl}/api/v1/inspection/verify`;

    this.logger.log(`Dispatching inspection metadata to AI pipeline: ${endpoint}`);

    try {
      const response = await firstValueFrom(
        this.httpService.post(endpoint, payload, {
          headers: {
            'Content-Type': 'application/json',
          },
        }),
      );
      this.logger.log(`AI Pipeline Response: Status ${response.status}`);
      return response.data;
    } catch (error: any) {
      this.logger.error(
        `Failed to notify Module 2 AI Pipeline: ${error.message}`,
        error.stack,
      );
      // Return a simulated response in dev mode to ensure operational robustness
      return {
        success: false,
        message: 'Mock fallback response - AI pipeline offline',
        mockVerdict: {
          damageCategory: 'STRUCTURAL_BODY',
          damageSeverity: 'MODERATE',
          estimatedRepairCost: 45.0,
          recommendedAction: 'REPAIR',
        },
      };
    }
  }
}
