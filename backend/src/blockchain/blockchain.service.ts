import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { VIEM_PROVIDER, ViemProvider } from 'src/provider/provider.viem';
import { DEPOSIT_ESCROW_ABI } from '../constants/contract';
import { BlockchainDepositsService } from './blockchain-deposits.service';
import { Address } from 'viem';

@Injectable()
export class BlockchainService implements OnModuleInit {
  private readonly logger = new Logger(BlockchainService.name);
  private readonly CONTRACT_ADDRESS: Address;

  constructor(
    @Inject(VIEM_PROVIDER) private readonly viem: ViemProvider,
    private readonly configService: ConfigService,
    private readonly blockchainDeposits: BlockchainDepositsService,
  ) {
    this.CONTRACT_ADDRESS = this.configService.getOrThrow('CONTRACT_ADDRESS');
  }

  onModuleInit() {
    this.watchDepositEvents();
  }

  watchDepositEvents() {
    this.logger.debug('Starting to watch Deposit events...');

    this.viem.watchContractEvent({
      abi: DEPOSIT_ESCROW_ABI,
      address: this.CONTRACT_ADDRESS,
      eventName: 'DepositCreated',
      onLogs: (logs) => {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const log = logs[0] as any;

        if (!log.args) return;

        const {
          depositId,
          depositor,
          beneficiary,
          depositAmount,
          periodStart,
          periodEnd,
          autoReleaseTime,
        } = log.args;

        void this.blockchainDeposits.processDepositCreatedEvent(
          depositId,
          depositor,
          beneficiary,
          depositAmount,
          periodStart,
          periodEnd,
          autoReleaseTime,
          log.blockNumber!,
        );
      },
      onError: (error) => {
        this.logger.error(`Error watching DepositCreated: ${error.message}`);
      },
    });
  }
}
