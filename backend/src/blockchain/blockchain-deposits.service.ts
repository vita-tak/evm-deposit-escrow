import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { DepositStatus } from 'generated/prisma/client';

@Injectable()
export class BlockchainDepositsService {
  private readonly logger = new Logger(BlockchainDepositsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async processDepositCreatedEvent(
    depositId: bigint,
    depositor: string,
    beneficiary: string,
    depositAmount: bigint,
    periodStart: bigint,
    periodEnd: bigint,
    autoReleaseTime: bigint,
    blockNumber: bigint,
  ) {
    this.logger.log(`Processing DepositCreated: ID ${depositId}`);

    try {
      await this.prisma.user.upsert({
        where: {
          walletAddress: depositor,
        },
        update: {},
        create: {
          walletAddress: depositor,
        },
      });

      await this.prisma.user.upsert({
        where: {
          walletAddress: beneficiary,
        },
        update: {},
        create: {
          walletAddress: beneficiary,
        },
      });

      await this.prisma.deposit.create({
        data: {
          onChainId: depositId.toString(),
          depositorAddress: depositor,
          beneficiaryAddress: beneficiary,
          depositAmount: depositAmount.toString(),
          periodStart: new Date(Number(periodStart) * 1000),
          periodEnd: new Date(Number(periodEnd) * 1000),
          autoReleaseTime: new Date(Number(autoReleaseTime) * 1000),
          status: DepositStatus.WAITING_FOR_DEPOSIT,
        },
      });
      this.logger.log(
        `DepositCreated ${depositId} processed successfully (block: ${blockNumber})`,
      );
    } catch (error) {
      this.logger.error(
        `Failed to process DepositCreated ${depositId}:`,
        error,
      );
    }
  }

  async processDepositPaidEvent(
    depositId: bigint,
    depositor: string,
    blockNumber: bigint,
  ) {
    this.logger.log(`Processing DepositPaid: ID ${depositId}`);

    try {
      const deposit = await this.prisma.deposit.findUnique({
        where: { onChainId: depositId.toString() },
      });

      if (!deposit) {
        this.logger.warn(`DepositPaid ${depositId} not found`);
        return;
      }

      await this.prisma.deposit.update({
        where: { id: deposit.id },
        data: {
          status: DepositStatus.ACTIVE,
        },
      });

      this.logger.log(
        `DepositPaid ${depositId} processed successfully (block: ${blockNumber})`,
      );
    } catch (error) {
      this.logger.error(`Failed to process DepositPaid ${depositId}:`, error);
    }
  }

  async processCleanExitConfirmedEvent(
    depositId: bigint,
    beneficiary: string,
    blockNumber: bigint,
    txHash: string,
  ) {
    try {
      this.logger.log(
        `Processing CleanExitConfirmed: depositId=${depositId}, beneficiary=${beneficiary}`,
      );

      const deposit = await this.prisma.deposit.findUnique({
        where: { onChainId: depositId.toString() },
      });

      if (!deposit) {
        this.logger.warn(
          `Deposit ${depositId} not found in database - might be syncing`,
        );
        return;
      }

      if (deposit.status !== DepositStatus.ACTIVE) {
        this.logger.error(
          `Invalid status for CleanExit: depositId=${depositId}, ` +
            `expected=ACTIVE, actual=${deposit.status}`,
        );
        return;
      }

      await this.prisma.deposit.update({
        where: { onChainId: depositId.toString() },
        data: {
          status: DepositStatus.COMPLETED,
        },
      });

      this.logger.log(
        `CleanExitConfirmed ${depositId} processed successfully (block: ${blockNumber})`,
      );
    } catch (error) {
      this.logger.error(
        `Failed to process CleanExitConfirmed ${depositId}:`,
        error,
      );
    }
  }
}
