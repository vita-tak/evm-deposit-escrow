'use client';

import { useState } from 'react';
import { useWriteContract } from 'wagmi';
import { parseUnits } from 'viem';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import {
  depositEscrowAddress,
  depositEscrowAbi,
} from '@/lib/contracts/deposit-escrow';

export default function LandlordPage() {
  const [depositorAddress, setDepositorAddress] = useState('');
  const [depositAmount, setDepositAmount] = useState('');
  const [periodStart, setPeriodStart] = useState('');
  const [periodEnd, setPeriodEnd] = useState('');

  const { writeContract, isPending, isSuccess, error } = useWriteContract();

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    const amountInSmallestUnit = parseUnits(depositAmount, 6);

    const startTimestamp = Math.floor(new Date(periodStart).getTime() / 1000);

    const endTimestamp = Math.floor(new Date(periodEnd).getTime() / 1000);

    writeContract({
      address: depositEscrowAddress,
      abi: depositEscrowAbi,
      functionName: 'createDeposit',
      args: [
        depositorAddress as `0x${string}`,
        amountInSmallestUnit,
        BigInt(startTimestamp),
        BigInt(endTimestamp),
      ],
    });
  };

  return (
    <div className='container mx-auto p-8'>
      <h1 className='text-3xl font-bold mb-6'>Landlord Dashboard</h1>

      <Card className='max-w-md'>
        <CardHeader>
          <CardTitle>Create New Deposit</CardTitle>
        </CardHeader>
        <CardContent className='space-y-4'>
          <div className='space-y-2'>
            <Label htmlFor='depositor'>Tenant Address</Label>
            <Input
              id='depositor'
              type='text'
              value={depositorAddress}
              onChange={(e) => setDepositorAddress(e.target.value)}
              placeholder='0x...'
            />
          </div>

          <div className='space-y-2'>
            <Label htmlFor='amount'>Deposit Amount (USDC)</Label>
            <Input
              id='amount'
              type='text'
              value={depositAmount}
              onChange={(e) => setDepositAmount(e.target.value)}
              placeholder='1000'
            />
          </div>

          <div className='space-y-2'>
            <Label htmlFor='start'>Period Start</Label>
            <Input
              id='start'
              type='date'
              value={periodStart}
              onChange={(e) => setPeriodStart(e.target.value)}
            />
          </div>

          <div className='space-y-2'>
            <Label htmlFor='end'>Period End</Label>
            <Input
              id='end'
              type='date'
              value={periodEnd}
              onChange={(e) => setPeriodEnd(e.target.value)}
            />
          </div>

          <Button
            onClick={handleSubmit}
            disabled={isPending}
            className='w-full'>
            {isPending ? 'Creating...' : 'Create Deposit'}
          </Button>

          {isSuccess && (
            <div className='p-4 bg-green-100 text-green-800 rounded-lg'>
              Deposit created successfully!
            </div>
          )}

          {error && (
            <div className='p-4 bg-red-100 text-red-800 rounded-lg text-sm'>
              Error: {error.message}
            </div>
          )}

          <div className='mt-8 p-4 bg-muted rounded-lg'>
            <h3 className='font-semibold mb-2 text-sm'>Debug:</h3>
            <pre className='text-xs overflow-auto'>
              {JSON.stringify(
                {
                  depositorAddress,
                  depositAmount,
                  periodStart,
                  periodEnd,
                },
                null,
                2
              )}
            </pre>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
