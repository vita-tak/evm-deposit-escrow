import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Address } from 'viem';
import { VIEM_PROVIDER, ViemProvider } from 'src/provider/provider.viem';
import { DEPOSIT_ESCROW_ABI } from '../constants/contract';
import { BlockchainDepositsService } from './blockchain-deposits.service';
import { BlockchainDisputesService } from './blockchain-disputes.service';

@Injectable()
export class BlockchainService implements OnModuleInit {
  private readonly logger = new Logger(BlockchainService.name);
  private readonly CONTRACT_ADDRESS: Address;

  constructor(
    @Inject(VIEM_PROVIDER) private readonly viem: ViemProvider,
    private readonly configService: ConfigService,
    private readonly blockchainDeposits: BlockchainDepositsService,
    private readonly blockchainDisputes: BlockchainDisputesService,
  ) {
    this.CONTRACT_ADDRESS = this.configService.getOrThrow('CONTRACT_ADDRESS');
  }

  onModuleInit() {
    this.watchDepositEvents();
    this.watchDisputeEvents();
  }

  watchDepositEvents() {
    this.logger.debug('Starting to watch Deposit events...');

    this.watchDepositCreatedEvent();
    this.watchDepositPaidEvent();
    this.watchCleanExitConfirmedEvent();
    this.watchAutoReleaseExecutedEvent();

    this.logger.log('Deposit event listeners successfully started');
  }

  watchDisputeEvents() {
    this.logger.debug('Starting to watch Dispute events...');

    this.watchDisputeRaisedEvent();

    this.logger.log('Dispute event listeners successfully started');
  }

  private watchDepositCreatedEvent() {
    this.viem.watchContractEvent({
      abi: DEPOSIT_ESCROW_ABI,
      address: this.CONTRACT_ADDRESS,
      eventName: 'DepositCreated',
      onLogs: (logs) => {
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

  private watchDepositPaidEvent() {
    this.viem.watchContractEvent({
      abi: DEPOSIT_ESCROW_ABI,
      address: this.CONTRACT_ADDRESS,
      eventName: 'DepositPaid',
      onLogs: (logs) => {
        const log = logs[0] as any;
        if (!log.args) return;

        const { depositId, depositor } = log.args;

        void this.blockchainDeposits.processDepositPaidEvent(
          depositId,
          depositor,
          log.blockNumber!,
        );
      },
      onError: (error) => {
        this.logger.error(`Error watching DepositPaid: ${error.message}`);
      },
    });
  }

  private watchCleanExitConfirmedEvent() {
    this.viem.watchContractEvent({
      address: this.CONTRACT_ADDRESS,
      abi: DEPOSIT_ESCROW_ABI,
      eventName: 'CleanExitConfirmed',
      onLogs: (logs) => {
        const log = logs[0] as any;
        if (!log.args) return;

        const { depositId, beneficiary } = log.args;

        void this.blockchainDeposits.processCleanExitConfirmedEvent(
          depositId,
          beneficiary,
          log.blockNumber!,
          log.transactionHash!,
        );
      },
      onError: (error) => {
        this.logger.error(
          `Error watching CleanExitConfirmed: ${error.message}`,
        );
      },
    });
  }

  private watchAutoReleaseExecutedEvent() {
    this.viem.watchContractEvent({
      address: this.CONTRACT_ADDRESS,
      abi: DEPOSIT_ESCROW_ABI,
      eventName: 'AutoReleaseExecuted',
      onLogs: (logs) => {
        const log = logs[0] as any;
        if (!log.args) return;

        const { depositId, depositor } = log.args;

        void this.blockchainDeposits.processAutoReleaseExecutedEvent(
          depositId,
          depositor,
          log.blockNumber!,
          log.transactionHash!,
        );
      },
      onError: (error) => {
        this.logger.error(
          `Error watching AutoReleaseExecuted: ${error.message}`,
        );
      },
    });
  }

  private watchDisputeRaisedEvent() {
    this.viem.watchContractEvent({
      address: this.CONTRACT_ADDRESS,
      abi: DEPOSIT_ESCROW_ABI,
      eventName: 'DisputeRaised',
      onLogs: async (logs) => {
        const log = logs[0] as any;
        if (!log.args) return;

        const { depositId, beneficiary, claimedAmount, evidenceHash } =
          log.args;

        const block = await this.viem.getBlock({
          blockNumber: log.blockNumber!,
        });

        void this.blockchainDisputes.processDisputeRaisedEvent(
          depositId,
          beneficiary,
          claimedAmount,
          evidenceHash,
          log.blockNumber!,
          log.transactionHash!,
          block.timestamp,
        );
      },
      onError: (error) => {
        this.logger.error(`Error watching DisputeRaised: ${error.message}`);
      },
    });
  }
}
