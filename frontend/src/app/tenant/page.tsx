'use client';

import { useAccount } from 'wagmi';
import { useState, useEffect } from 'react';
import { getDepositsByDepositor } from '@/lib/api';
import { DepositCard } from '@/components/DepositCard';

export default function TenantDashboard() {
  const { address, isConnected } = useAccount();
  const [deposits, setDeposits] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function fetchDeposits() {
      if (!address) {
        setLoading(false);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        console.log('Fetching deposits for:', address);
        const data = await getDepositsByDepositor(address);

        console.log('Received deposits:', data.length);
        setDeposits(data);
      } catch (err) {
        console.error('Error fetching deposits:', err);
        setError(err.message);
      } finally {
        setLoading(false);
      }
    }

    fetchDeposits();
  }, [address]);

  if (!isConnected) {
    return (
      <div className='container mx-auto py-8'>
        <h1 className='text-3xl font-bold mb-4'>Tenant Deposits</h1>
        <p className='text-gray-600'>
          Please connect your wallet to view your deposits.
        </p>
      </div>
    );
  }

  if (loading) {
    return (
      <div className='container mx-auto py-8'>
        <h1 className='text-3xl font-bold mb-4'>Tenant Deposits</h1>
        <p>Loading deposits...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className='container mx-auto py-8'>
        <h1 className='text-3xl font-bold mb-4'>Tenant Deposits</h1>
        <p className='text-red-600'>Error: {error}</p>
      </div>
    );
  }

  const pendingDeposits = deposits.filter(
    (d) => d.status === 'WAITING_FOR_DEPOSIT'
  );
  const otherDeposits = deposits.filter(
    (d) => d.status !== 'WAITING_FOR_DEPOSIT'
  );

  return (
    <div className='container mx-auto py-8'>
      <h1 className='text-3xl font-bold mb-8'>Tenant Deposits</h1>
      <p className='text-sm text-gray-600 mb-8'>Connected as: {address}</p>

      {/* Pending Deposits */}
      {pendingDeposits.length > 0 && (
        <div className='mb-8'>
          <h2 className='text-xl font-semibold mb-4'>
            Pending Payment ({pendingDeposits.length})
          </h2>
          <div className='grid gap-4 md:grid-cols-2 lg:grid-cols-3'>
            {pendingDeposits.map((deposit) => (
              <DepositCard key={deposit.id} deposit={deposit} />
            ))}
          </div>
        </div>
      )}

      {/* Other Deposits */}
      {otherDeposits.length > 0 && (
        <div>
          <h2 className='text-xl font-semibold mb-4'>
            All Deposits ({otherDeposits.length})
          </h2>
          <div className='grid gap-4 md:grid-cols-2 lg:grid-cols-3'>
            {otherDeposits.map((deposit) => (
              <DepositCard key={deposit.id} deposit={deposit} />
            ))}
          </div>
        </div>
      )}

      {/* Empty state */}
      {deposits.length === 0 && (
        <div className='p-8 bg-gray-50 rounded-lg text-center'>
          <p className='text-gray-600'>No deposits found.</p>
        </div>
      )}
    </div>
  );
}
