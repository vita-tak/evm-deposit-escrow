import { useState, useEffect } from 'react';
import { useWriteContract } from 'wagmi';
import { parseUnits } from 'viem';
import { Dialog, DialogContent, DialogFooter, DialogHeader } from './ui/dialog';
import { DialogDescription, DialogTitle } from '@radix-ui/react-dialog';
import { Button } from './ui/button';
import { Slider } from './ui/slider';
import {
  depositEscrowAddress,
  depositEscrowAbi,
} from '@/lib/contracts/deposit-escrow';

interface ResolverDecisionDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  depositId: string;
  depositAmount: string;
  landlordClaim?: string;
  landlordEvidence?: string;
  tenantResponse?: string;
}

export function ResolverDecisionDialog({
  open,
  onOpenChange,
  depositId,
  depositAmount,
  landlordClaim,
  landlordEvidence,
  tenantResponse,
}: ResolverDecisionDialogProps) {
  const [percentage, setPercentage] = useState(50);

  const { writeContract, isSuccess, isPending } = useWriteContract();

  useEffect(() => {
    if (isSuccess) {
      onOpenChange(false);
      setPercentage(50);
    }
  }, [isSuccess, onOpenChange]);

  const handleSubmit = () => {
    const totalAmount = BigInt(depositAmount);
    const amountToBeneficiary = (totalAmount * BigInt(percentage)) / 100n;

    writeContract({
      address: depositEscrowAddress,
      abi: depositEscrowAbi,
      functionName: 'makeResolverDecision',
      args: [BigInt(depositId), amountToBeneficiary],
    });
  };

  const formatUSDC = (amount: string) => {
    const num = parseInt(amount) / 1_000_000;
    return num.toFixed(2);
  };

  const totalAmount = parseInt(depositAmount);
  const landlordGets = (totalAmount * percentage) / 100;
  const tenantGets = totalAmount - landlordGets;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className='max-w-2xl'>
        <DialogHeader>
          <DialogTitle>Make Decision - Deposit #{depositId}</DialogTitle>
          <DialogDescription>
            Review evidence and decide the split
          </DialogDescription>
        </DialogHeader>

        {/* Evidence Section */}
        <div className='space-y-4'>
          {/* Landlord Evidence */}
          <div className='p-3 bg-red-50 rounded-lg space-y-2'>
            <p className='text-sm font-semibold text-red-800'>Landlord Claim</p>
            {landlordClaim && (
              <p className='text-sm text-red-700'>
                Claimed: {formatUSDC(landlordClaim)} USDC
              </p>
            )}
            {landlordEvidence && (
              <p className='text-xs text-red-600 break-all'>
                Evidence: {landlordEvidence}
              </p>
            )}
          </div>

          {/* Tenant Response */}
          {tenantResponse ? (
            <div className='p-3 bg-blue-50 rounded-lg space-y-2'>
              <p className='text-sm font-semibold text-blue-800'>
                Tenant Response
              </p>
              <p className='text-xs text-blue-600 break-all'>
                Evidence: {tenantResponse}
              </p>
            </div>
          ) : (
            <div className='p-3 bg-yellow-50 rounded-lg'>
              <p className='text-sm text-yellow-800'>
                Tenant has not responded
              </p>
            </div>
          )}
        </div>

        <div className='flex gap-2 mb-4'>
          <Button variant='outline' size='sm' onClick={() => setPercentage(0)}>
            Full Refund (Tenant)
          </Button>
          <Button variant='outline' size='sm' onClick={() => setPercentage(50)}>
            50/50 Split
          </Button>
          <Button
            variant='outline'
            size='sm'
            onClick={() => setPercentage(100)}>
            Grant Full Claim (Landlord)
          </Button>
        </div>

        {/* Slider Section */}
        <div className='space-y-4 pt-4'>
          <div className='space-y-2'>
            <p className='text-sm font-semibold'>Decision:</p>
            <p className='text-xs text-gray-600'>
              Drag slider to split the deposit amount
            </p>
          </div>

          <Slider
            value={[percentage]}
            onValueChange={(value) => setPercentage(value[0])}
            max={100}
            step={1}
            className='w-full'
          />

          {/* Visual Split Display */}
          <div className='flex items-center gap-2 text-sm'>
            <div className='flex-1 text-left'>
              <p className='text-gray-600'>Tenant gets:</p>
              <p className='font-bold text-lg'>
                {formatUSDC(tenantGets.toString())} USDC
              </p>
              <p className='text-xs text-gray-500'>{100 - percentage}%</p>
            </div>

            <div className='text-2xl text-gray-400'>⟷</div>

            <div className='flex-1 text-right'>
              <p className='text-gray-600'>Landlord gets:</p>
              <p className='font-bold text-lg'>
                {formatUSDC(landlordGets.toString())} USDC
              </p>
              <p className='text-xs text-gray-500'>{percentage}%</p>
            </div>
          </div>
        </div>

        <DialogFooter>
          <Button variant='outline' onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button onClick={handleSubmit} disabled={isPending}>
            {isPending ? 'Submitting...' : 'Submit Decision'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
