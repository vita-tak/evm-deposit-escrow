import { Controller, Get, Param } from '@nestjs/common';
import { DepositsService } from './deposits.service';

@Controller('deposits')
export class DepositsController {
  constructor(private readonly depositsService: DepositsService) {}

  @Get()
  async findAll() {
    return this.depositsService.findAll();
  }

  @Get('depositor/:address')
  async findByDepositor(@Param('address') address: string) {
    return this.depositsService.findByDepositor(address);
  }

  @Get('beneficiary/:address')
  async findByBeneficiary(@Param('address') address: string) {
    return this.depositsService.findByBeneficiary(address);
  }

  @Get(':onChainId')
  async findById(@Param('onChainId') onChainId: string) {
    return this.depositsService.findById(BigInt(onChainId));
  }
}
