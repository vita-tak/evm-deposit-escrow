/*
  Warnings:

  - You are about to drop the column `beneficiaryId` on the `Deposit` table. All the data in the column will be lost.
  - You are about to drop the column `depositorId` on the `Deposit` table. All the data in the column will be lost.
  - Added the required column `beneficiaryAddress` to the `Deposit` table without a default value. This is not possible if the table is not empty.
  - Added the required column `depositorAddress` to the `Deposit` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE "Deposit" DROP CONSTRAINT "Deposit_beneficiaryId_fkey";

-- DropForeignKey
ALTER TABLE "Deposit" DROP CONSTRAINT "Deposit_depositorId_fkey";

-- AlterTable
ALTER TABLE "Deposit" DROP COLUMN "beneficiaryId",
DROP COLUMN "depositorId",
ADD COLUMN     "beneficiaryAddress" TEXT NOT NULL,
ADD COLUMN     "depositorAddress" TEXT NOT NULL;

-- AddForeignKey
ALTER TABLE "Deposit" ADD CONSTRAINT "Deposit_depositorAddress_fkey" FOREIGN KEY ("depositorAddress") REFERENCES "User"("walletAddress") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Deposit" ADD CONSTRAINT "Deposit_beneficiaryAddress_fkey" FOREIGN KEY ("beneficiaryAddress") REFERENCES "User"("walletAddress") ON DELETE RESTRICT ON UPDATE CASCADE;
