import { Controller } from '@nestjs/common';
import { GatewayRagService } from './gateway-rag.service';

@Controller('gateway-rag')
export class GatewayRagController {
  constructor(private readonly gatewayRagService: GatewayRagService) {}
}
