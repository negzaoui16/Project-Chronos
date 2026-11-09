import { Module } from '@nestjs/common';
import { ChronosBackendController } from './chronos-backend.controller';
import { ChronosBackendService } from './chronos-backend.service';

@Module({
  controllers: [ChronosBackendController],
  providers: [ChronosBackendService],
})
export class ChronosBackendModule {}
