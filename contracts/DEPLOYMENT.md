# Deployment History - DepositEscrow

## Latest Deployment (Polygon Amoy Testnet)

**Datum:** [2025-12-14]

### Contract Information

- **Contract Address:** `0x7B68741408a448876574845b14F1BE526d4010b2`
- **Transaction Hash:** `0x9e390064d88f2850a69de226d6c1641acc1ee4e7f5185a1fd64f4da5ee5ceaf8`
- **Block Number:** 30520418
- **Network:** Polygon Amoy (Chain ID: 80002)
- **Verification:** Verified on Sourcify

### Get ABI:

From `/contracts` directory:

**View in terminal (truncated):**

```bash
cat out/DepositEscrow.sol/DepositEscrow.json | jq '.abi'
```

**Export to file (recommended):**

```bash
cat out/DepositEscrow.sol/DepositEscrow.json | jq '.abi' > DepositEscrow.abi.json
```

**Copy to backend:**

```bash
cp DepositEscrow.abi.json ../backend/src/constants/
```

### Constructor Parameters

- **Resolver:** `0x0D10d7320a99384Bc874336CAE56745e0e8b9341`
- **Platform Fee:** 100 (1%)
- **Fee Recipient:** `0x0D10d7320a99384Bc874336CAE56745e0e8b9341`
- **USDC Token:** `0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582` (Circle Testnet USDC)

### Gas Costs

- **Gas Used:** 2,276,806
- **Gas Price:** 35 gwei
- **Total Cost:** 0.0797 POL

### Explorer Links

- **Polygonscan:** https://amoy.polygonscan.com/address/0x7B68741408a448876574845b14F1BE526d4010b2
- **Transaction:** https://amoy.polygonscan.com/tx/0x9e390064d88f2850a69de226d6c1641acc1ee4e7f5185a1fd64f4da5ee5ceaf8

---

## Previous Deployments

### Old Contract (DEPRECATED)

- **Address:** `0x7973D492096Bc16F4e40bCB842d5f259223741D7`
- **Status:** Deprecated - Do not use!
