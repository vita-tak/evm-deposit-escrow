import { Module } from '@nestjs/common';
import { BlockchainService } from './blockchain.service';
import { BlockchainDepositsService } from './blockchain-deposits.service';
import { BlockchainDisputesService } from './blockchain-disputes.service';
import { PrismaModule } from '../prisma/prisma.module';
import { ProviderModule } from '../provider/provider.module';

@Module({
  imports: [PrismaModule, ProviderModule],
  providers: [
    BlockchainService,
    BlockchainDepositsService,
    BlockchainDisputesService,
  ],
  exports: [BlockchainService],
})
export class BlockchainModule {}
