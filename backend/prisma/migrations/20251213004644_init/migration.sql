-- CreateEnum
CREATE TYPE "DepositStatus" AS ENUM ('WAITING_FOR_DEPOSIT', 'ACTIVE', 'COMPLETED', 'DISPUTED', 'RESOLVED');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "walletAddress" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Deposit" (
    "id" TEXT NOT NULL,
    "depositId" INTEGER NOT NULL,
    "depositAmount" BIGINT NOT NULL,
    "periodStart" TIMESTAMP(3) NOT NULL,
    "periodEnd" TIMESTAMP(3) NOT NULL,
    "autoReleaseTime" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "status" "DepositStatus" NOT NULL,
    "depositorId" TEXT NOT NULL,
    "beneficiaryId" TEXT NOT NULL,

    CONSTRAINT "Deposit_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Dispute" (
    "id" TEXT NOT NULL,
    "claimedAmount" BIGINT NOT NULL,
    "evidenceHash" TEXT NOT NULL,
    "responseHash" TEXT,
    "depositorResponded" BOOLEAN NOT NULL DEFAULT false,
    "disputeStartTime" TIMESTAMP(3) NOT NULL,
    "disputeDeadline" TIMESTAMP(3) NOT NULL,
    "depositId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Dispute_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "blockchain_state" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "lastProcessedBlock" BIGINT NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "blockchain_state_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_walletAddress_key" ON "User"("walletAddress");

-- CreateIndex
CREATE UNIQUE INDEX "Deposit_depositId_key" ON "Deposit"("depositId");

-- CreateIndex
CREATE UNIQUE INDEX "Dispute_depositId_key" ON "Dispute"("depositId");

-- AddForeignKey
ALTER TABLE "Deposit" ADD CONSTRAINT "Deposit_depositorId_fkey" FOREIGN KEY ("depositorId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Deposit" ADD CONSTRAINT "Deposit_beneficiaryId_fkey" FOREIGN KEY ("beneficiaryId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Dispute" ADD CONSTRAINT "Dispute_depositId_fkey" FOREIGN KEY ("depositId") REFERENCES "Deposit"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
