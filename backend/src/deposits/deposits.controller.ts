import { Controller, Get, Param } from '@nestjs/common';
import { DepositsService } from './deposits.service';

@Controller('deposits')
export class DepositsController {
  constructor(private readonly depositsService: DepositsService) {}

  @Get()
  async findAll() {
    return this.depositsService.findAll();
  }

  @Get(':onChainId')
  async findById(@Param('onChainId') onChainId: string) {
    return this.depositsService.findById(BigInt(onChainId));
  }
}
