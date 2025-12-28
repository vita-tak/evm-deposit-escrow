const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001';

export async function getDeposits() {
  const response = await fetch(`${API_URL}/deposits`);
  if (!response.ok) {
    throw new Error('Failed to fetch');
  }
  return response.json();
}

export async function getDepositsByDepositor(depositorAddress: string) {
  const response = await fetch(
    `${API_URL}/deposits/depositor/${depositorAddress}`
  );
  if (!response.ok) {
    throw new Error('Failed to fetch deposits by depositor');
  }
  return response.json();
}

export async function getDepositsByBeneficiary(beneficiaryAddress: string) {
  const response = await fetch(
    `${API_URL}/deposits/beneficiary/${beneficiaryAddress}`
  );
  if (!response.ok) {
    throw new Error('Failed to fetch deposits by beneficiary');
  }
  return response.json();
}

export async function getDisputeByDepositId(onChainId: string) {
  const response = await fetch(`${API_URL}/disputes/${onChainId}`);

  if (!response.ok) {
    if (response.status === 404) {
      return null;
    }
    throw new Error('Failed to fetch dispute');
  }

  return response.json();
}

export async function getAllDisputes() {
  const response = await fetch(`${API_URL}/disputes`);
  if (!response.ok) {
    throw new Error('Failed to fetch disputes');
  }
  return response.json();
}
