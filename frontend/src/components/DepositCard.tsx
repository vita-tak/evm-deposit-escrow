'use client';

import { useState, useEffect } from 'react';
import { useWriteContract, useAccount } from 'wagmi';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { usdcAddress, usdcAbi } from '@/lib/contracts/usdc';
import { RaiseDisputeDialog } from '@/components/RaiseDisputeDialog';
import {
  depositEscrowAddress,
  depositEscrowAbi,
} from '@/lib/contracts/deposit-escrow';

interface Deposit {
  id: string;
  onChainId: string;
  depositAmount: string;
  status: string;
  depositorAddress: string;
  beneficiaryAddress: string;
  periodStart: string;
  periodEnd: string;
  autoReleaseTime: string;
}

interface DepositCardProps {
  deposit: Deposit;
}

export function DepositCard({ deposit }: DepositCardProps) {
  const { address, isConnected } = useAccount();

  const [isApproved, setIsApproved] = useState(false);
  const [isDialogOpen, setIsDialogOpen] = useState(false);

  const isDepositor =
    address?.toLowerCase() === deposit.depositorAddress.toLowerCase();
  const isBeneficiary =
    address?.toLowerCase() === deposit.beneficiaryAddress.toLowerCase();

  const {
    writeContract: approveUSDC,
    isPending: isApproving,
    isSuccess: approveSuccess,
  } = useWriteContract();

  const {
    writeContract: payDeposit,
    isPending: isPaying,
    isSuccess: paySuccess,
  } = useWriteContract();

  const {
    writeContract: confirmCleanExit,
    isPending: isConfirming,
    isSuccess: confirmSuccess,
  } = useWriteContract();

  const calculateTotal = () => {
    const depositAmount = BigInt(deposit.depositAmount);
    const platformFee = 100n;
    const fee = (depositAmount * platformFee) / 10000n;
    return depositAmount + fee;
  };

  const handleApprove = () => {
    const totalAmount = calculateTotal();

    if (!address || !isConnected) {
      alert('Please connect your wallet first!');
      return;
    }

    approveUSDC({
      address: usdcAddress,
      abi: usdcAbi,
      functionName: 'approve',
      args: [depositEscrowAddress, totalAmount],
      account: address,
    });
  };

  const handlePay = () => {
    const depositId = BigInt(deposit.onChainId);

    payDeposit({
      address: depositEscrowAddress,
      abi: depositEscrowAbi,
      functionName: 'payDeposit',
      args: [depositId],
      account: address,
    });
  };

  const handleConfirmCleanExit = () => {
    const depositId = BigInt(deposit.onChainId);

    confirmCleanExit({
      address: depositEscrowAddress,
      abi: depositEscrowAbi,
      functionName: 'confirmCleanExit',
      args: [depositId],
      account: address,
    });
  };

  useEffect(() => {
    if (approveSuccess) {
      setIsApproved(true);
    }
  }, [approveSuccess]);

  const handleRaiseDispute = () => {
    setIsDialogOpen(true);
  };

  const formatUSDC = (amount: string) => {
    const num = parseInt(amount) / 1_000_000;
    return num.toFixed(2);
  };

  const formatAddress = (address: string) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString();
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'WAITING_FOR_DEPOSIT':
        return 'bg-yellow-100 text-yellow-800';
      case 'ACTIVE':
        return 'bg-blue-100 text-blue-800';
      case 'DISPUTED':
        return 'bg-red-100 text-red-800';
      case 'COMPLETED':
        return 'bg-green-100 text-green-800';
      case 'RESOLVED':
        return 'bg-purple-100 text-purple-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  return (
    <Card>
      <CardHeader>
        <div className='flex justify-between items-start'>
          <CardTitle>Deposit #{deposit.onChainId}</CardTitle>
          <Badge className={getStatusColor(deposit.status)}>
            {deposit.status}
          </Badge>
        </div>
      </CardHeader>

      <CardContent className='space-y-4'>
        <div>
          <span className='text-sm text-gray-600'>Amount:</span>
          <span className='ml-2 font-bold text-lg'>
            {formatUSDC(deposit.depositAmount)} USDC
          </span>
        </div>

        <div>
          <span className='text-sm text-gray-600'>Landlord:</span>
          <span className='ml-2 font-mono text-sm'>
            {formatAddress(deposit.beneficiaryAddress)}
          </span>
        </div>

        <div>
          <span className='text-sm text-gray-600'>Period:</span>
          <span className='ml-2 text-sm'>
            {formatDate(deposit.periodStart)} → {formatDate(deposit.periodEnd)}
          </span>
        </div>

        {deposit.status === 'ACTIVE' && (
          <div className='pt-4'>
            <div className='p-3 bg-blue-50 rounded-lg text-sm text-blue-800'>
              Deposit active. Auto-release:{' '}
              {formatDate(deposit.autoReleaseTime)}
            </div>
          </div>
        )}

        {deposit.status === 'COMPLETED' && (
          <div className='pt-4'>
            <div className='p-3 bg-green-50 rounded-lg text-sm text-green-800'>
              Deposit returned!
            </div>
          </div>
        )}

        {/* Tenant actions - IF user is depositor */}
        {deposit.status === 'WAITING_FOR_DEPOSIT' && isDepositor && (
          <div className='space-y-3 pt-4'>
            {/* Approve Button */}
            <Button
              variant='outline'
              className='w-full'
              onClick={handleApprove}
              disabled={isApproving || isApproved}>
              {isApproving
                ? 'Approving...'
                : isApproved
                ? 'Approved'
                : 'Approve USDC'}
            </Button>

            {/* Pay Button */}
            <Button
              className='w-full'
              onClick={handlePay}
              disabled={!isApproved || isPaying}>
              {isPaying ? 'Paying...' : 'Pay Deposit'}
            </Button>

            {/* Success messages */}
            {paySuccess && (
              <div className='p-3 bg-green-50 rounded-lg text-sm text-green-800'>
                Deposit paid successfully! Refresh to see updated status...
              </div>
            )}

            {confirmSuccess && (
              <div className='p-3 bg-green-50 rounded-lg text-sm text-green-800'>
                Clean exit confirmed! Deposit returned to tenant.
              </div>
            )}

            {/* Fee info */}
            {!isApproved && (
              <div className='p-3 bg-blue-50 rounded-lg text-xs text-blue-800'>
                💡 Total: {formatUSDC(calculateTotal().toString())} USDC
                (includes 1% fee)
              </div>
            )}
          </div>
        )}

        {/* Landlord actions - IF user is beneficiary */}
        {deposit.status === 'ACTIVE' && isBeneficiary && (
          <div className='space-y-3 pt-4'>
            <Button
              onClick={handleConfirmCleanExit}
              disabled={isConfirming}
              className='w-full'>
              {isConfirming ? 'Confirming...' : 'Confirm Clean Exit'}
            </Button>

            <Button onClick={handleRaiseDispute}>Raise Dispute</Button>

            <RaiseDisputeDialog
              open={isDialogOpen}
              onOpenChange={setIsDialogOpen}
              depositId={deposit.onChainId}
              depositAmount={deposit.depositAmount}
            />
          </div>
        )}
      </CardContent>
    </Card>
  );
}
