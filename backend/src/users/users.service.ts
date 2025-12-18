import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async findByAddress(walletAddress: string) {
    return await this.prisma.user.findUnique({
      where: { walletAddress },
    });
  }

  async getUserDeposits(walletAddress: string) {
    const user = await this.prisma.user.findUnique({
      where: { walletAddress },
      include: {
        depositsAsDepositor: true,
        depositsAsBeneficiary: true,
      },
    });

    if (!user) return [];
    return [...user.depositsAsDepositor, ...user.depositsAsBeneficiary];
  }
}
