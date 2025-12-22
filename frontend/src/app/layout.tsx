import type { Metadata } from 'next';
import './globals.css';
import TanstackProvider from '@/providers/tanstack-provider';
import WagmiProviderComponent from '@/providers/wagmi-provider';
import RainbowKitProviderComponent from '@/providers/rainbowkit-provider';

export const metadata: Metadata = {
  title: 'Blip - Secure Rental Deposits',
  description: 'Blockchain-based rental deposit escrow system',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang='en'>
      <body className='antialiased'>
        <TanstackProvider>
          <WagmiProviderComponent>
            <RainbowKitProviderComponent>
              {children}
            </RainbowKitProviderComponent>
          </WagmiProviderComponent>
        </TanstackProvider>
      </body>
    </html>
  );
}
