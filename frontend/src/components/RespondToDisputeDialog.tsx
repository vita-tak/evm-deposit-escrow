import { useState, useEffect } from 'react';
import { useWriteContract } from 'wagmi';
import {
  depositEscrowAddress,
  depositEscrowAbi,
} from '@/lib/contracts/deposit-escrow';
import { Label } from '@radix-ui/react-label';
import { Input } from './ui/input';
import { Button } from './ui/button';
import { DialogFooter, DialogHeader } from './ui/dialog';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from '@radix-ui/react-dialog';

interface RespondToDisputeDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  depositId: string;
  claimedAmount?: string;
  landlordEvidence?: string;
}

export function RespondToDisputeDialog({
  open,
  onOpenChange,
  depositId,
  claimedAmount,
  landlordEvidence,
}: RespondToDisputeDialogProps) {
  const [responseHash, setResponseHash] = useState('');

  const { writeContract, isSuccess, isPending } = useWriteContract();

  const handleSubmit = () => {
    writeContract({
      address: depositEscrowAddress,
      abi: depositEscrowAbi,
      functionName: 'respondToDispute',
      args: [BigInt(depositId), responseHash],
    });
  };

  useEffect(() => {
    if (isSuccess) {
      onOpenChange(false);
      setResponseHash('');
    }
  }, [isSuccess, onOpenChange]);

  const isSubmitDisabled = !responseHash;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Respond to Dispute</DialogTitle>
          <DialogDescription>
            Provide your response and evidence
          </DialogDescription>
        </DialogHeader>

        {/* Show landlord claim */}
        <div className='p-3 bg-red-50 rounded-lg space-y-2'>
          <p className='text-sm font-semibold text-red-800'>Landlord Claim</p>
          {claimedAmount && (
            <p className='text-sm text-red-700'>
              Amount claimed:{' '}
              {claimedAmount &&
                (parseInt(claimedAmount) / 1_000_000).toFixed(2)}{' '}
              USDC
            </p>
          )}
          {landlordEvidence && (
            <p className='text-xs text-red-600 break-all'>
              Evidence: {landlordEvidence}
            </p>
          )}
        </div>

        {/* Tenant response input */}
        <div className='space-y-2'>
          <Label htmlFor='response'>Your Evidence Hash (IPFS)</Label>
          <Input
            id='response'
            type='text'
            placeholder='ipfs://Qm...'
            value={responseHash}
            onChange={(e) => setResponseHash(e.target.value)}
          />
        </div>

        <DialogFooter>
          <Button variant='outline' onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button
            onClick={handleSubmit}
            disabled={isSubmitDisabled || isPending}>
            {isPending ? 'Submitting...' : 'Submit Response'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
