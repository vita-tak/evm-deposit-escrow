import { Provider } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createPublicClient, http, PublicClient } from 'viem';
import { polygonAmoy } from 'viem/chains';

export const VIEM_PROVIDER = 'VIEM_PROVIDER';

export type ViemProvider = PublicClient;

export const ViemProvider: Provider = {
  provide: VIEM_PROVIDER,
  useFactory: (configService: ConfigService) => {
    const rpcUrl = configService.get<string>('RPC_URL');

    if (!rpcUrl) {
      throw new Error('RPC_URL is missing in .env file!');
    }

    return createPublicClient({
      chain: polygonAmoy,
      transport: http(rpcUrl, {
        timeout: 30_000,
        retryCount: 3,
      }),
      pollingInterval: 12_000,
      batch: {
        multicall: {
          wait: 16,
        },
      },
      cacheTime: 4_000,
    });
  },
  inject: [ConfigService],
};
