import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ExternalAiService } from './external-ai.service';

@Module({
  imports: [HttpModule],
  providers: [ExternalAiService],
  exports: [ExternalAiService],
})
export class ExternalAiModule {}
