import { Module } from '@nestjs/common';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';
import { PrismaModule } from '../prisma/prisma.module';
import { CloudinaryModule } from '../common/cloudinary/cloudinary.module';
import { ExternalAiModule } from '../common/external-ai/external-ai.module';
import { EscrowModule } from '../blockchain/escrow.module';
import { Module2ApiModule } from '../module2/module2-api/module2-api.module';

@Module({
  imports: [PrismaModule, CloudinaryModule, ExternalAiModule, EscrowModule, Module2ApiModule],
  controllers: [BookingsController],
  providers: [BookingsService],
  exports: [BookingsService],
})
export class BookingsModule {}
