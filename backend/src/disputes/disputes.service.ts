import { Injectable } from '@nestjs/common';
import { PrismaService } from 'src/prisma/prisma.service';

@Injectable()
export class DisputesService {
  constructor(private readonly prisma: PrismaService) {}

  findAll() {
    return this.prisma.dispute.findMany();
  }

  async findByOnChainId(onChainId: string) {
    const deposit = await this.prisma.deposit.findUnique({
      where: { onChainId },
      include: { dispute: true },
    });
    return deposit?.dispute || null;
  }
}
