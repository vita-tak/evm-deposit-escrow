import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { DepositStatus } from 'generated/prisma/client';

@Injectable()
export class BlockchainDisputesService {
  private readonly logger = new Logger(BlockchainDisputesService.name);

  constructor(private readonly prisma: PrismaService) {}

  async processDisputeRaisedEvent(
    depositId: bigint,
    beneficiary: string,
    claimedAmount: bigint,
    evidenceHash: string,
    blockNumber: bigint,
    txHash: string,
    blockTimestamp: bigint,
  ) {
    try {
      this.logger.log(
        `Processing DisputeRaised: depositId=${depositId}, beneficiary=${beneficiary}`,
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
          `Invalid status for DisputeRaised: depositId=${depositId}, ` +
            `expected=ACTIVE, actual=${deposit.status}`,
        );
        return;
      }

      await this.prisma.$transaction([
        this.prisma.deposit.update({
          where: { onChainId: depositId.toString() },
          data: { status: DepositStatus.DISPUTED },
        }),

        this.prisma.dispute.create({
          data: {
            depositId: deposit.id,
            claimedAmount: BigInt(claimedAmount.toString()),
            evidenceHash: evidenceHash,
            disputeStartTime: new Date(Number(blockTimestamp) * 1000),
            disputeDeadline: new Date(
              Number(blockTimestamp) * 1000 + 14 * 24 * 60 * 60 * 1000,
            ),
            depositorResponded: false,
          },
        }),
      ]);

      this.logger.log(
        `DisputeRaised ${depositId} processed successfully (block: ${blockNumber})`,
      );
    } catch (error) {
      this.logger.error(`Failed to process DisputeRaised ${depositId}:`, error);
    }
  }

  async processDepositorRespondedEvent(
    depositId: bigint,
    depositor: string,
    responseHash: string,
    blockNumber: bigint,
    txHash: string,
  ) {
    try {
      this.logger.log(
        `Processing DepositorResponded: depositId=${depositId}, depositor=${depositor}`,
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

      const dispute = await this.prisma.dispute.findUnique({
        where: { depositId: deposit.id },
      });

      if (!dispute) {
        this.logger.error(`Dispute not found for deposit ${depositId}`);
        return;
      }

      await this.prisma.dispute.update({
        where: { depositId: deposit.id },
        data: {
          responseHash: responseHash,
          depositorResponded: true,
        },
      });

      this.logger.log(
        `DepositorResponded ${depositId} processed successfully (block: ${blockNumber})`,
      );
    } catch (error) {
      this.logger.error(
        `Failed to process DepositorResponded ${depositId}:`,
        error,
      );
    }
  }

  async processResolverDecisionEvent(
    depositId: bigint,
    resolver: string,
    amountToDepositor: bigint,
    amountToBeneficiary: bigint,
    blockNumber: bigint,
    txHash: string,
  ) {
    try {
      this.logger.log(
        `Processing ResolverDecision: depositId=${depositId}, resolver=${resolver}, amountToDepositor=${amountToDepositor}, amountToBeneficiary=${amountToBeneficiary}`,
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

      if (deposit.status !== DepositStatus.DISPUTED) {
        this.logger.error(
          `Invalid status for ResolverDecision: depositId=${depositId}, ` +
            `expected=DISPUTED, actual=${deposit.status}`,
        );
        return;
      }

      await this.prisma.deposit.update({
        where: { id: deposit.id },
        data: {
          status: DepositStatus.RESOLVED,
        },
      });

      this.logger.log(
        `ResolverDecision ${depositId} processed successfully (block: ${blockNumber})`,
      );
    } catch (error) {
      this.logger.error(
        `Failed to process ResolverDecision ${depositId}:`,
        error,
      );
    }
  }

  async processDisputeTimeoutEvent(
    depositId: bigint,
    depositor: string,
    amount: bigint,
    blockNumber: bigint,
    txHash: string,
  ) {
    try {
      this.logger.log(
        `Processing DisputeTimeout: depositId=${depositId}, depositor=${depositor}, amount=${amount}`,
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

      if (deposit.status !== DepositStatus.DISPUTED) {
        this.logger.error(
          `Invalid status for DisputeTimeout: depositId=${depositId}, ` +
            `expected=DISPUTED, actual=${deposit.status}`,
        );
        return;
      }

      await this.prisma.deposit.update({
        where: { id: deposit.id },
        data: {
          status: DepositStatus.RESOLVED,
        },
      });

      this.logger.log(
        `DisputeTimeout ${depositId} processed successfully (block: ${blockNumber})`,
      );
    } catch (error) {
      this.logger.error(
        `Failed to process DisputeTimeout ${depositId}:`,
        error,
      );
    }
  }
}
