/*
  Warnings:

  - You are about to drop the column `depositId` on the `Deposit` table. All the data in the column will be lost.
  - A unique constraint covering the columns `[onChainId]` on the table `Deposit` will be added. If there are existing duplicate values, this will fail.
  - Added the required column `onChainId` to the `Deposit` table without a default value. This is not possible if the table is not empty.

*/
-- DropIndex
DROP INDEX "Deposit_depositId_key";

-- AlterTable
ALTER TABLE "Deposit" DROP COLUMN "depositId",
ADD COLUMN     "onChainId" TEXT NOT NULL,
ALTER COLUMN "depositAmount" SET DATA TYPE TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "Deposit_onChainId_key" ON "Deposit"("onChainId");
