'use client';

import { WagmiProvider, createConfig, http } from 'wagmi';
import { polygonAmoy } from 'wagmi/chains';
import { injected } from 'wagmi/connectors';

export const wagmiConfig = createConfig({
  chains: [polygonAmoy],
  connectors: [injected()],
  transports: {
    [polygonAmoy.id]: http(),
  },
});

export default function WagmiProviderComponent({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <WagmiProvider config={wagmiConfig} reconnectOnMount={true}>
      {children}
    </WagmiProvider>
  );
}
