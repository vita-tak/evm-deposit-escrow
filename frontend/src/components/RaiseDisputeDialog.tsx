import { useState, useEffect } from 'react';
import { Dialog, DialogContent, DialogFooter, DialogHeader } from './ui/dialog';
import { useWriteContract } from 'wagmi';
import {
  depositEscrowAddress,
  depositEscrowAbi,
} from '@/lib/contracts/deposit-escrow';
import { parseUnits } from 'viem';
import { DialogDescription, DialogTitle } from '@radix-ui/react-dialog';
import { Input } from './ui/input';
import { Button } from './ui/button';
import { Label } from '@radix-ui/react-label';

interface RaiseDisputeDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  depositId: string;
  depositAmount: string;
}

export function RaiseDisputeDialog({
  open,
  onOpenChange,
  depositId,
  depositAmount,
}: RaiseDisputeDialogProps) {
  const [claimedAmount, setClaimedAmount] = useState('');
  const [evidenceHash, setEvidenceHash] = useState('');

  const { writeContract, isSuccess, isPending } = useWriteContract();

  useEffect(() => {
    if (isSuccess) {
      onOpenChange(false);
      setClaimedAmount('');
      setEvidenceHash('');
    }
  }, [isSuccess, onOpenChange]);

  const handleSubmit = () => {
    const claimedAmountInSmallestUnit = parseUnits(claimedAmount, 6);

    const depositIdBigInt = BigInt(depositId);

    writeContract({
      address: depositEscrowAddress,
      abi: depositEscrowAbi,
      functionName: 'raiseDispute',
      args: [depositIdBigInt, claimedAmountInSmallestUnit, evidenceHash],
    });
  };

  const maxAmount = parseInt(depositAmount) / 1_000_000;

  const isSubmitDisabled =
    !claimedAmount ||
    !evidenceHash ||
    parseFloat(claimedAmount) > maxAmount ||
    parseFloat(claimedAmount) <= 0;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Raise Dispute</DialogTitle>
          <DialogDescription>Dispute time</DialogDescription>
        </DialogHeader>

        {/* Input 1: Claimed Amount */}
        <div className='space-y-2'>
          <Label htmlFor='amount'>Claimed Amount (max: {maxAmount} USDC)</Label>
          <Input
            id='amount'
            type='text'
            placeholder='300'
            value={claimedAmount}
            onChange={(e) => setClaimedAmount(e.target.value)}
          />
        </div>

        {/* Input 2: Evidence Hash */}
        <div className='space-y-2'>
          <Label htmlFor='evidence'>Evidence Hash (IPFS)</Label>
          <Input
            id='evidence'
            type='text'
            placeholder='ipfs://Qm...'
            value={evidenceHash}
            onChange={(e) => setEvidenceHash(e.target.value)}
          />
        </div>

        <DialogFooter>
          <Button variant='outline' onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button
            onClick={handleSubmit}
            disabled={isSubmitDisabled || isPending}>
            Submit Dispute
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
