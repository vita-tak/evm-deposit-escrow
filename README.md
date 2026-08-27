# Blip Rental Deposits

A modular, blockchain-based escrow application for secure stablecoin 
deposit management. Chainlink Automation for trustless, time-based 
releases and dispute timeout enforcement. Built with the flexibility 
to support various deposit scenarios.

Example implementation: Rental deposits (landlord ↔ tenant)

Deployed to Polygon Amoy testnet.

## How it works

The escrow contract holds stablecoin deposits on-chain and releases 
them automatically based on predefined conditions, with no intermediary 
needed. Chainlink Automation enforces time-based releases and dispute 
timeouts trustlessly, meaning no one can interfere with the release 
logic once a deposit is locked.

Disputes are handled on-chain with a timeout mechanism: if no 
resolution is reached within the dispute window, the contract 
resolves automatically.

<img width="634" height="288" alt="biprental" src="https://github.com/user-attachments/assets/97316919-a08c-4464-a447-565f87185534" /> 
<img width="640" height="228" alt="biprental2" src="https://github.com/user-attachments/assets/bf20f72f-8198-421d-acdb-f7dba85ea309" />

## Tech Stack

Deployed to Polygon Amoy testnet. [View contract on Polyscan](https://amoy.polygonscan.com/address/0x70bf1cA32Bf17bd05C014E80cAb4bf770a2c3E6B)

| Layer | Technology |
|---|---|
| Smart Contracts | Solidity, Foundry, Chainlink Automation |
| Frontend | React, wagmi, viem |
| Backend | NestJS, TypeScript, PostgreSQL, Prisma |
| Tools | Docker, Git |

## Key Features

**Trustless releases** — Chainlink Automation triggers releases without manual intervention

**Dispute resolution** — on-chain dispute mechanism with automatic timeout enforcement

**Modular design** — core escrow logic is reusable across deposit scenarios beyond rental

**Non-custodial** — funds are held by the contract, never by a central party

## Why this project

Rental deposits are a broken system. Landlords hold funds with no 
enforcement mechanism, and tenants have little recourse. This project 
explores how smart contracts and trustless automation can replace the 
intermediary entirely, making the rules transparent and self-enforcing 
from day one.

## Getting Started

### Prerequisites
Foundry installed, Node.js 18+, PostgreSQL running locally

### Contracts
```bash
cd contracts
forge install
forge build
forge test
```

### Backend
```bash
cd backend
cp .env.example .env
pnpm install
npx prisma migrate dev
pnpm run start:dev
```

### Frontend
```bash
cd frontend
pnpm install
pnpm run dev
```

### Docker
```bash
docker-compose up
```
