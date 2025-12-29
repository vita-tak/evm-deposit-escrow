'use client';

import { useState, useEffect } from 'react';
import { useAccount } from 'wagmi';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { getAllDisputes } from '@/lib/api';
import { ResolverDecisionDialog } from '@/components/ResolverDecisionDialog';

export default function ResolverPage() {
  const { address, isConnected } = useAccount();
  const [disputes, setDisputes] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedDispute, setSelectedDispute] = useState<any>(null);

  useEffect(() => {
    async function fetchDisputes() {
      try {
        setLoading(true);
        setError(null);

        const data = await getAllDisputes();
        console.log('Fetched disputes:', data);

        const disputedOnly = data.filter(
          (d: any) => d.deposit?.status === 'DISPUTED'
        );

        setDisputes(disputedOnly);
      } catch (err) {
        console.error('Error fetching disputes:', err);
        setError('Failed to load disputes');
      } finally {
        setLoading(false);
      }
    }

    fetchDisputes();
  }, []);

  const formatUSDC = (amount: string) => {
    const num = parseInt(amount) / 1_000_000;
    return num.toFixed(2);
  };

  const formatAddress = (address: string) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  if (!isConnected) {
    return (
      <div className='container mx-auto py-8'>
        <h1 className='text-3xl font-bold mb-8'>Resolver Panel</h1>
        <p className='text-gray-600'>
          Please connect your wallet to access the resolver panel.
        </p>
      </div>
    );
  }

  return (
    <div className='container mx-auto py-8'>
      <h1 className='text-3xl font-bold mb-8'>Resolver Panel</h1>

      {loading && (
        <div className='p-8 bg-gray-50 rounded-lg text-center'>
          <p>Loading disputes...</p>
        </div>
      )}

      {error && (
        <div className='p-4 bg-red-50 rounded-lg text-red-800'>
          Error: {error}
        </div>
      )}

      {!loading && !error && disputes.length === 0 && (
        <div className='p-8 bg-gray-50 rounded-lg text-center'>
          <p className='text-gray-600'>No pending disputes to resolve.</p>
        </div>
      )}

      {!loading && !error && disputes.length > 0 && (
        <div className='space-y-4'>
          <p className='text-sm text-gray-600'>
            {disputes.length} pending dispute(s)
          </p>

          <div className='grid gap-4 md:grid-cols-2 lg:grid-cols-3'>
            {disputes.map((dispute) => (
              <Card key={dispute.id}>
                <CardHeader>
                  <div className='flex justify-between items-start'>
                    <CardTitle>Deposit #{dispute.deposit?.onChainId}</CardTitle>
                    <Badge className='bg-red-100 text-red-800'>DISPUTED</Badge>
                  </div>
                </CardHeader>

                <CardContent className='space-y-4'>
                  {/* Deposit Info */}
                  <div className='grid grid-cols-2 gap-4 text-sm'>
                    <div>
                      <span className='text-gray-600'>Total Deposit:</span>
                      <p className='font-bold'>
                        {formatUSDC(dispute.deposit?.depositAmount)} USDC
                      </p>
                    </div>

                    <div>
                      <span className='text-gray-600'>Landlord Claims:</span>
                      <p className='font-bold text-red-600'>
                        {formatUSDC(dispute.claimedAmount)} USDC
                      </p>
                    </div>
                  </div>

                  {/* Parties */}
                  <div className='p-3 bg-gray-50 rounded-lg space-y-2 text-sm'>
                    <div>
                      <span className='text-gray-600'>Landlord: </span>
                      <span className='font-mono'>
                        {formatAddress(dispute.deposit?.beneficiaryAddress)}
                      </span>
                    </div>
                    <div>
                      <span className='text-gray-600'>Tenant: </span>
                      <span className='font-mono'>
                        {formatAddress(dispute.deposit?.depositorAddress)}
                      </span>
                    </div>
                  </div>

                  {/* Evidence */}
                  <div className='space-y-2 text-sm'>
                    <div className='p-2 bg-red-50 rounded'>
                      <p className='text-xs text-gray-600'>
                        Landlord Evidence:
                      </p>
                      <p className='text-xs font-mono break-all'>
                        {dispute.evidenceHash}
                      </p>
                    </div>

                    {dispute.responseHash && (
                      <div className='p-2 bg-blue-50 rounded'>
                        <p className='text-xs text-gray-600'>
                          Tenant Response:
                        </p>
                        <p className='text-xs font-mono break-all'>
                          {dispute.responseHash}
                        </p>
                      </div>
                    )}

                    {!dispute.depositorResponded && (
                      <p className='text-xs text-yellow-600'>
                        Tenant has not responded yet
                      </p>
                    )}
                  </div>

                  {/* Action Button */}
                  <Button
                    className='w-full'
                    size='lg'
                    onClick={() => setSelectedDispute(dispute)}>
                    Make Decision
                  </Button>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      )}
      {selectedDispute && (
        <ResolverDecisionDialog
          open={!!selectedDispute}
          onOpenChange={(open) => !open && setSelectedDispute(null)}
          depositId={selectedDispute.deposit?.onChainId}
          depositAmount={selectedDispute.deposit?.depositAmount}
          landlordClaim={selectedDispute.claimedAmount}
          landlordEvidence={selectedDispute.evidenceHash}
          tenantResponse={selectedDispute.responseHash}
        />
      )}
    </div>
  );
}
