// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DepositEscrow} from "../src/DepositEscrow.sol";

contract DepositEscrowTest is Test {
    DepositEscrow public escrow;
    
    address public resolver = address(1);
    address public beneficiary = address(2);
    address public depositor = address(3);
    
    uint256 public constant PLATFORM_FEE = 100;
    uint256 public constant DEPOSIT_AMOUNT = 1 ether;
    
    function setUp() public {
        escrow = new DepositEscrow(resolver, PLATFORM_FEE);
        
        vm.deal(depositor, 10 ether);
        vm.deal(beneficiary, 10 ether);
    }

    function test_CreateContract_Success() public {
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        
        vm.prank(beneficiary);
        escrow.createContract(depositor, DEPOSIT_AMOUNT, start, end);
    
        DepositEscrow.DepositContract memory contract_ = escrow.getContract(1);
        
        assertEq(contract_.id, 1);
        assertEq(contract_.depositor, depositor);
        assertEq(contract_.beneficiary, beneficiary);
        assertEq(contract_.depositAmount, DEPOSIT_AMOUNT);
        assertEq(uint256(contract_.status), uint256(DepositEscrow.ContractStatus.WAITING_FOR_DEPOSIT));
        assertEq(contract_.autoReleaseTime, end + 7 days);
    }

    function test_CreateContract_RevertsIfDepositIsZero() public {
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.DepositMustBeGreaterThanZero.selector);
        escrow.createContract(depositor, 0, start, end);
    }

    function test_CreateContract_RevertsIfEndBeforeStart() public {
        uint256 start = block.timestamp + 30 days;
        uint256 end = start - 1 days;
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.EndMustBeAfterStart.selector);
        escrow.createContract(depositor, DEPOSIT_AMOUNT, start, end);
    }

    function test_CreateContract_RevertsIfDepositorIsZero() public {
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.InvalidDepositorAddress.selector);
        escrow.createContract(address(0), DEPOSIT_AMOUNT, start, end);
    }

    function _createTestContract() internal returns (uint256) {
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        
        uint256 contractId = escrow.nextContractId();
        
        vm.prank(beneficiary);
        escrow.createContract(depositor, DEPOSIT_AMOUNT, start, end);
        
        return contractId;
    }

    function test_PayDeposit_Success() public {
        uint256 contractId = _createTestContract();
        
        uint256 fee = (DEPOSIT_AMOUNT * PLATFORM_FEE) / 10000;
        uint256 totalRequired = DEPOSIT_AMOUNT + fee;
        
        uint256 depositorBalanceBefore = depositor.balance;
        uint256 escrowBalanceBefore = address(escrow).balance;
        
        vm.prank(depositor);
        escrow.payDeposit{value: totalRequired}(contractId);
        
        assertEq(depositor.balance, depositorBalanceBefore - totalRequired);
        assertEq(address(escrow).balance, escrowBalanceBefore + totalRequired);
        
        DepositEscrow.DepositContract memory contract_ = escrow.getContract(contractId);
        assertEq(uint256(contract_.status), uint256(DepositEscrow.ContractStatus.ACTIVE));
    }

    function test_PayDeposit_RevertsIfNotDepositor() public {
        uint256 contractId = _createTestContract();
        
        uint256 fee = (DEPOSIT_AMOUNT * PLATFORM_FEE) / 10000;
        uint256 totalRequired = DEPOSIT_AMOUNT + fee;
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.OnlyDepositorCanPay.selector);
        escrow.payDeposit{value: totalRequired}(contractId);
    }

    function test_PayDeposit_RevertsIfIncorrectAmount() public {
        uint256 contractId = _createTestContract();
        
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.IncorrectAmount.selector);
        escrow.payDeposit{value: 1}(contractId);
    }

    function test_PayDeposit_RevertsIfContractDoesNotExist() public {
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.ContractDoesNotExist.selector);
        escrow.payDeposit{value: DEPOSIT_AMOUNT}(999);
    }

    function test_PayDeposit_RevertsIfAlreadyPaid() public {
        uint256 contractId = _createTestContract();
        
        uint256 fee = (DEPOSIT_AMOUNT * PLATFORM_FEE) / 10000;
        uint256 totalRequired = DEPOSIT_AMOUNT + fee;
        
        vm.prank(depositor);
        escrow.payDeposit{value: totalRequired}(contractId);
        
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.InvalidStatus.selector);
        escrow.payDeposit{value: totalRequired}(contractId);
    }

    function _createAndPayContract() internal returns (uint256) {
        uint256 contractId = _createTestContract();
        
        uint256 fee = (DEPOSIT_AMOUNT * PLATFORM_FEE) / 10000;
        uint256 totalRequired = DEPOSIT_AMOUNT + fee;
        
        vm.prank(depositor);
        escrow.payDeposit{value: totalRequired}(contractId);
        
        return contractId;
    }

    function test_ConfirmCleanExit_Success() public {
        uint256 contractId = _createAndPayContract();
        
        DepositEscrow.DepositContract memory contract_ = escrow.getContract(contractId);
        vm.warp(contract_.contractEnd + 1);
        
        uint256 depositorBalanceBefore = depositor.balance;
        
        vm.prank(beneficiary);
        escrow.confirmCleanExit(contractId);
        
        assertEq(depositor.balance, depositorBalanceBefore + DEPOSIT_AMOUNT);
        
        contract_ = escrow.getContract(contractId);
        assertEq(uint256(contract_.status), uint256(DepositEscrow.ContractStatus.COMPLETED));
    }

    function test_ConfirmCleanExit_RevertsIfNotBeneficiary() public {
        uint256 contractId = _createAndPayContract();
        
        DepositEscrow.DepositContract memory contract_ = escrow.getContract(contractId);
        vm.warp(contract_.contractEnd + 1);
        
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.OnlyBeneficiaryCanConfirm.selector);
        escrow.confirmCleanExit(contractId);
    }

    function test_ConfirmCleanExit_RevertsIfBeforeEnd() public {
        uint256 contractId = _createAndPayContract();

        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.ContractPeriodNotEnded.selector);
        escrow.confirmCleanExit(contractId);
    }

    function test_ConfirmCleanExit_RevertsIfNotActive() public {
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        
        vm.prank(beneficiary);
        escrow.createContract(depositor, DEPOSIT_AMOUNT, start, end);
        
        vm.warp(end + 1);
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.InvalidStatus.selector);
        escrow.confirmCleanExit(1);
    }

    function _createPayAndEndContract() internal returns (uint256) {
        uint256 contractId = _createAndPayContract();
        
        DepositEscrow.DepositContract memory contract_ = escrow.getContract(contractId);
        vm.warp(contract_.contractEnd + 1);
        
        return contractId;
    }

    function _createAndRaiseDispute() internal returns (uint256) {
        uint256 contractId = _createPayAndEndContract();
        
        vm.prank(beneficiary);
        escrow.raiseDispute(contractId, 300, "QmEvidence123");
        
        return contractId;
    }

    function test_RaiseDispute_Success() public {
        uint256 contractId = _createPayAndEndContract();
        
        uint256 claimedAmount = 300;
        string memory evidenceHash = "QmTest123";
        
        vm.prank(beneficiary);
        escrow.raiseDispute(contractId, claimedAmount, evidenceHash);
        
        DepositEscrow.DepositContract memory contract_ = escrow.getContract(contractId);
        assertEq(uint256(contract_.status), uint256(DepositEscrow.ContractStatus.DISPUTED));
        
        (uint256 claimed, string memory evidence, , bool responded, uint256 startTime) = escrow.disputes(contractId);
        assertEq(claimed, claimedAmount);
        assertEq(evidence, evidenceHash);
        assertEq(responded, false);
        assertEq(startTime, block.timestamp);
    }

    function test_RaiseDispute_EmitsEvent() public {
        uint256 contractId = _createPayAndEndContract();
        
        uint256 claimedAmount = 300;
        string memory evidenceHash = "QmTest123";
        
        vm.expectEmit(true, true, false, true);
        emit DepositEscrow.DisputeRaised(contractId, beneficiary, claimedAmount, evidenceHash);
        
        vm.prank(beneficiary);
        escrow.raiseDispute(contractId, claimedAmount, evidenceHash);
    }

    function test_RaiseDispute_RevertsIfNotBeneficiary() public {
        uint256 contractId = _createPayAndEndContract();
        
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.OnlyBeneficiaryCanRaiseDispute.selector);
        escrow.raiseDispute(contractId, 300, "QmTest");
    }

    function test_RaiseDispute_RevertsIfContractDoesNotExist() public {
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.ContractDoesNotExist.selector);
        escrow.raiseDispute(999, 300, "QmTest");
    }

    function test_RaiseDispute_RevertsIfNotActive() public {
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        
        vm.prank(beneficiary);
        escrow.createContract(depositor, DEPOSIT_AMOUNT, start, end);
        
        vm.warp(end + 1);
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.InvalidStatus.selector);
        escrow.raiseDispute(1, 300, "QmTest");
    }

    function test_RaiseDispute_RevertsIfBeforeContractEnd() public {
        uint256 contractId = _createAndPayContract();
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.ContractPeriodNotEnded.selector);
        escrow.raiseDispute(contractId, 300, "QmTest");
    }

    function test_RaiseDispute_RevertsIfClaimedAmountIsZero() public {
        uint256 contractId = _createPayAndEndContract();
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.DepositMustBeGreaterThanZero.selector);
        escrow.raiseDispute(contractId, 0, "QmTest");
    }

    function test_RaiseDispute_RevertsIfClaimedAmountExceedsDeposit() public {
        uint256 contractId = _createPayAndEndContract();
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.AmountExceedsDeposit.selector);
        escrow.raiseDispute(contractId, DEPOSIT_AMOUNT + 1, "QmTest");
    }

    function test_RespondToDispute_Success() public {
        uint256 contractId = _createAndRaiseDispute();
        
        string memory responseHash = "QmResponse123";
        
        vm.prank(depositor);
        escrow.respondToDispute(contractId, responseHash);
        
        (, , string memory response, bool responded, ) = escrow.disputes(contractId);
        assertEq(response, responseHash);
        assertEq(responded, true);
    }

    function test_RespondToDispute_EmitsEvent() public {
        uint256 contractId = _createAndRaiseDispute();
        
        string memory responseHash = "QmResponse123";
        
        vm.expectEmit(true, true, false, true);
        emit DepositEscrow.DepositorRespondedToDispute(contractId, depositor, responseHash);
        
        vm.prank(depositor);
        escrow.respondToDispute(contractId, responseHash);
    }

    function test_RespondToDispute_RevertsIfNotDepositor() public {
        uint256 contractId = _createAndRaiseDispute();
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.OnlyDepositorCanRespond.selector);
        escrow.respondToDispute(contractId, "QmResponse");
    }

    function test_RespondToDispute_RevertsIfContractDoesNotExist() public {
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.ContractDoesNotExist.selector);
        escrow.respondToDispute(999, "QmResponse");
    }

    function test_RespondToDispute_RevertsIfNotDisputed() public {
        uint256 contractId = _createPayAndEndContract();
        
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.InvalidStatus.selector);
        escrow.respondToDispute(contractId, "QmResponse");
    }

    function test_RespondToDispute_RevertsIfAlreadyResponded() public {
        uint256 contractId = _createAndRaiseDispute();
        
        vm.prank(depositor);
        escrow.respondToDispute(contractId, "QmResponse1");
        
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.AlreadyResponded.selector);
        escrow.respondToDispute(contractId, "QmResponse2");
    }

    function test_MakeResolverDecision_Success() public {
        uint256 contractId = _createAndRaiseDispute();
        
        uint256 amountToBeneficiary = 300;
        uint256 amountToDepositor = DEPOSIT_AMOUNT - amountToBeneficiary;
        
        uint256 beneficiaryBalanceBefore = beneficiary.balance;
        uint256 depositorBalanceBefore = depositor.balance;
        
        vm.prank(resolver);
        escrow.makeResolverDecision(contractId, amountToBeneficiary);
        
        assertEq(beneficiary.balance, beneficiaryBalanceBefore + amountToBeneficiary);
        assertEq(depositor.balance, depositorBalanceBefore + amountToDepositor);
        
        DepositEscrow.DepositContract memory contract_ = escrow.getContract(contractId);
        assertEq(uint256(contract_.status), uint256(DepositEscrow.ContractStatus.RESOLVED));
    }

    function test_MakeResolverDecision_EmitsEvent() public {
        uint256 contractId = _createAndRaiseDispute();
        
        uint256 amountToBeneficiary = 300;
        uint256 amountToDepositor = DEPOSIT_AMOUNT - amountToBeneficiary;
        
        vm.expectEmit(true, true, false, true);
        emit DepositEscrow.ResolverDecisionMade(contractId, resolver, amountToDepositor, amountToBeneficiary);
        
        vm.prank(resolver);
        escrow.makeResolverDecision(contractId, amountToBeneficiary);
    }

    function test_MakeResolverDecision_FullRefundToDepositor() public {
        uint256 contractId = _createAndRaiseDispute();
        
        uint256 depositorBalanceBefore = depositor.balance;
        uint256 beneficiaryBalanceBefore = beneficiary.balance;  
        
        vm.prank(resolver);
        escrow.makeResolverDecision(contractId, 0);
        
        assertEq(depositor.balance, depositorBalanceBefore + DEPOSIT_AMOUNT);
        assertEq(beneficiary.balance, beneficiaryBalanceBefore); 
    }

    function test_MakeResolverDecision_FullAmountToBeneficiary() public {
        uint256 contractId = _createAndRaiseDispute();
        
        uint256 beneficiaryBalanceBefore = beneficiary.balance;
        uint256 depositorBalanceBefore = depositor.balance;
        
        vm.prank(resolver);
        escrow.makeResolverDecision(contractId, DEPOSIT_AMOUNT);
        
        assertEq(beneficiary.balance, beneficiaryBalanceBefore + DEPOSIT_AMOUNT);
        assertEq(depositor.balance, depositorBalanceBefore);
    }

    function test_MakeResolverDecision_Split5050() public {
        uint256 contractId = _createAndRaiseDispute();
        
        uint256 half = DEPOSIT_AMOUNT / 2;
        
        uint256 beneficiaryBalanceBefore = beneficiary.balance;
        uint256 depositorBalanceBefore = depositor.balance;
        
        vm.prank(resolver);
        escrow.makeResolverDecision(contractId, half);
        
        assertEq(beneficiary.balance, beneficiaryBalanceBefore + half);
        assertEq(depositor.balance, depositorBalanceBefore + half);
    }

    function test_MakeResolverDecision_RevertsIfNotResolver() public {
        uint256 contractId = _createAndRaiseDispute();
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.OnlyResolverCanDecide.selector);
        escrow.makeResolverDecision(contractId, 300);
    }

    function test_MakeResolverDecision_RevertsIfContractDoesNotExist() public {
        vm.prank(resolver);
        vm.expectRevert(DepositEscrow.ContractDoesNotExist.selector);
        escrow.makeResolverDecision(999, 300);
    }

    function test_MakeResolverDecision_RevertsIfNotDisputed() public {
        uint256 contractId = _createPayAndEndContract();
        
        vm.prank(resolver);
        vm.expectRevert(DepositEscrow.InvalidStatus.selector);
        escrow.makeResolverDecision(contractId, 300);
    }

    function test_MakeResolverDecision_RevertsIfAmountExceedsDeposit() public {
        uint256 contractId = _createAndRaiseDispute();
        
        vm.prank(resolver);
        vm.expectRevert(DepositEscrow.AmountExceedsDeposit.selector);
        escrow.makeResolverDecision(contractId, DEPOSIT_AMOUNT + 1);
    }

    function test_ResolveDisputeByTimeout_Success() public {
        uint256 contractId = _createAndRaiseDispute();

        vm.warp(block.timestamp + 14 days + 1);
        
        uint256 depositorBalanceBefore = depositor.balance;
        
        escrow.resolveDisputeByTimeout(contractId);
        
        assertEq(depositor.balance, depositorBalanceBefore + DEPOSIT_AMOUNT);
        
        DepositEscrow.DepositContract memory contract_ = escrow.getContract(contractId);
        assertEq(uint256(contract_.status), uint256(DepositEscrow.ContractStatus.RESOLVED));
    }

    function test_ResolveDisputeByTimeout_EmitsEvent() public {
        uint256 contractId = _createAndRaiseDispute();
        
        vm.warp(block.timestamp + 14 days + 1);
        
        vm.expectEmit(true, true, false, true);
        emit DepositEscrow.DisputeResolvedByTimeout(contractId, depositor, DEPOSIT_AMOUNT);
        
        escrow.resolveDisputeByTimeout(contractId);
    }

    function test_ResolveDisputeByTimeout_RevertsIfTooEarly() public {
        uint256 contractId = _createAndRaiseDispute();

        vm.warp(block.timestamp + 13 days);
        
        vm.expectRevert(DepositEscrow.DisputeStillActive.selector);
        escrow.resolveDisputeByTimeout(contractId);
    }

    function test_ResolveDisputeByTimeout_RevertsIfNotDisputed() public {
        uint256 contractId = _createPayAndEndContract();
        
        vm.warp(block.timestamp + 14 days + 1);
        
        vm.expectRevert(DepositEscrow.InvalidStatus.selector);
        escrow.resolveDisputeByTimeout(contractId);
    }

    function test_ResolveDisputeByTimeout_RevertsIfContractDoesNotExist() public {
        vm.warp(block.timestamp + 14 days + 1);
        
        vm.expectRevert(DepositEscrow.ContractDoesNotExist.selector);
        escrow.resolveDisputeByTimeout(999);
    }
}