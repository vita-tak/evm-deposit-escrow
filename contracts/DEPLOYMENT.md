# Deployment History - DepositEscrow

## Latest Deployment (Polygon Amoy Testnet)

**Datum:** 2024-12-15  
**Status:** ACTIVE

### Contract Information

- **Contract Address:** `0x70bf1cA32Bf17bd05C014E80cAb4bf770a2c3E6B`
- **Transaction Hash:** `0xb1e3d0771d4cd88685f9bedcbade71a1a75dbe213be63d281eb17654a8ec70cf`
- **Block Number:** 30537576
- **Network:** Polygon Amoy (Chain ID: 80002)
- **Verification:** Verified on Sourcify

### Constructor Parameters

- **Resolver:** `0x0D10d7320a99384Bc874336CAE56745e0e8b9341`
- **Platform Fee:** 100 (1%)
- **Fee Recipient:** `0x0D10d7320a99384Bc874336CAE56745e0e8b9341`
- **USDC Token:** `0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582` (Circle Testnet USDC)

### Gas Costs

- **Gas Used:** 2,300,738
- **Gas Price:** 35 gwei
- **Total Cost:** 0.0805 POL (~0.45 SEK)

### Explorer Links

- **Polygonscan:** https://amoy.polygonscan.com/address/0x70bf1cA32Bf17bd05C014E80cAb4bf770a2c3E6B
- **Transaction:** https://amoy.polygonscan.com/tx/0xb1e3d0771d4cd88685f9bedcbade71a1a75dbe213be63d281eb17654a8ec70cf

### Get ABI

From `/contracts` directory:

**View in terminal:**

```bash
cat out/DepositEscrow.sol/DepositEscrow.json | jq '.abi'
```

**Export to file:**

```bash
forge inspect DepositEscrow abi > DepositEscrow.abi.json
```

**Copy to backend:**

```bash
cp DepositEscrow.abi.json ../backend/src/constants/
```

---

## 🔧 Backend Integration

**Update backend `.env`:**

```env
CONTRACT_ADDRESS="0x70bf1cA32Bf17bd05C014E80cAb4bf770a2c3E6B"
```

**Update ABI:**

```bash
cd contracts
forge inspect DepositEscrow abi > DepositEscrow.abi.json
cp DepositEscrow.abi.json ../backend/src/constants/
cd ../backend
pnpm run build
node dist/main.js
```

---

## 📜 Previous Deployments

### Deployment #1 (DEPRECATED)

- **Address:** `0x7B68741408a448876574845b14F1BE526d4010b2`
- **Block:** 30520418
- **Status:** Deprecated (Old event signatures)
- **Reason:** Missing `periodStart` and `autoReleaseTime` in events

---

## 🎯 Key Changes in Latest Version

- Added `periodStart` to `DepositCreated` event
- Added `autoReleaseTime` to `DepositCreated` event
- Updated all event signatures to match backend expectations
- Full compatibility with backend event listeners

---

## 🔗 Quick Links

- **Contract Source:** `contracts/src/DepositEscrow.sol`
- **Tests:** `contracts/test/DepositEscrow.t.sol`
- **Deploy Script:** `contracts/script/Deploy.s.sol`
