import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DepositsService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll() {
    return this.prisma.deposit.findMany({
      include: {
        dispute: true,
      },
    });
  }

  async findById(onChainId: bigint) {
    return this.prisma.deposit.findUnique({
      where: { onChainId: onChainId.toString() },
      include: {
        dispute: true,
      },
    });
  }
}
