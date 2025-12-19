import { Controller, Get, Param } from '@nestjs/common';
import { DisputesService } from './disputes.service';

@Controller('disputes')
export class DisputesController {
  constructor(private readonly disputesService: DisputesService) {}

  @Get()
  findAll() {
    return this.disputesService.findAll();
  }

  @Get(':onChainId')
  async findByOnChainId(@Param('onChainId') onChainId: string) {
    return this.disputesService.findByOnChainId(onChainId);
  }
}
