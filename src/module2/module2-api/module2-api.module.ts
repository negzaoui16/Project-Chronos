import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { Module2ApiService } from './module2-api.service';
import { GlueService } from './glue.service';
import { Module2ApiController } from './module2-api.controller';

@Module({
  imports: [HttpModule.register({ timeout: 300000 })], // 5 min - Agent 4 can take 2-3 min for 3 regions
  controllers: [Module2ApiController],
  providers: [Module2ApiService, GlueService],
  exports: [Module2ApiService],
})
export class Module2ApiModule {}
