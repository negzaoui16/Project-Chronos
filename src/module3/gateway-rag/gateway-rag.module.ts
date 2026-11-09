import { Module } from '@nestjs/common';
import { GatewayRagController } from './gateway-rag.controller';
import { GatewayRagService } from './gateway-rag.service';

@Module({
  controllers: [GatewayRagController],
  providers: [GatewayRagService],
})
export class GatewayRagModule {}
