import { Controller } from '@nestjs/common';
import { ChronosBackendService } from './chronos-backend.service';

@Controller('chronos')
export class ChronosBackendController {
  constructor(private readonly chronosBackendService: ChronosBackendService) {}
}
