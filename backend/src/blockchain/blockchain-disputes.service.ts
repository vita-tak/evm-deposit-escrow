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
}
