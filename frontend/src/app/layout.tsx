import type { Metadata } from 'next';
import { Plus_Jakarta_Sans, Inter } from 'next/font/google'; // Note: Space_Grotesk med underscore!
import './globals.css';
import TanstackProvider from '@/providers/tanstack-provider';
import WagmiProviderComponent from '@/providers/wagmi-provider';
import RainbowKitProviderComponent from '@/providers/rainbowkit-provider';
import { Navbar } from '@/components/layout/NavBar';

export const metadata: Metadata = {
  title: 'Blip - Secure Rental Deposits',
  description: 'Blockchain-based rental deposit escrow system',
};

const plusJakartaSans = Plus_Jakarta_Sans({
  subsets: ['latin'],
  variable: '--font-plus-jakarta-sans',
  display: 'swap',
});

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
});

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang='en'>
      <body
        className={`${inter.variable} ${plusJakartaSans.variable} font-sans antialiased`}>
        <TanstackProvider>
          <WagmiProviderComponent>
            <RainbowKitProviderComponent>
              <Navbar />
              {children}
            </RainbowKitProviderComponent>
          </WagmiProviderComponent>
        </TanstackProvider>
      </body>
    </html>
  );
}
