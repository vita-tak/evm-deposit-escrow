import { ConnectButton } from '@rainbow-me/rainbowkit';

export default function Home() {
  return (
    <div className='min-h-screen flex flex-col items-center justify-center p-8'>
      <div className='max-w-2xl w-full space-y-8 text-center'>
        <h1 className='text-4xl font-bold'>Welcome to Blip Rental Deposits!</h1>

        <p className='text-lg text-muted-foreground'>
          Secure rental deposits on blockchain
        </p>

        <div className='flex justify-center'>
          <ConnectButton />
        </div>
      </div>
    </div>
  );
}
