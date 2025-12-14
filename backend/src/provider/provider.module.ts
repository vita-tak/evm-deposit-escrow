import { Module } from '@nestjs/common';
import { ViemProvider } from './provider.viem';

@Module({
  providers: [ViemProvider],
  exports: [ViemProvider],
})
export class ProviderModule {}
