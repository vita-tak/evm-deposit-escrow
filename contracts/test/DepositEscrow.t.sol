// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DepositEscrow} from "../src/DepositEscrow.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DepositEscrowTest is Test {
    DepositEscrow public escrow;
    ERC20Mock public usdc;
    
    address public resolver = address(1);
    address public beneficiary = address(2);
    address public depositor = address(3);
    
    uint256 public constant PLATFORM_FEE = 100;
    uint256 public constant DEPOSIT_AMOUNT = 1000e6;
    
    function setUp() public {
        usdc = new ERC20Mock();
        escrow = new DepositEscrow(resolver, PLATFORM_FEE, address(usdc));
        usdc.mint(depositor, 10000e6);
        vm.prank(depositor);
        usdc.approve(address(escrow), type(uint256).max);
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
        
        vm.prank(beneficiary);
        escrow.createContract(depositor, DEPOSIT_AMOUNT, start, end);
        
        return 1;
    }
    
    function test_PayDeposit_Success() public {
        uint256 contractId = _createTestContract();
        
        uint256 fee = (DEPOSIT_AMOUNT * PLATFORM_FEE) / 10000;
        uint256 totalRequired = DEPOSIT_AMOUNT + fee;
        
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        uint256 escrowBalanceBefore = usdc.balanceOf(address(escrow));
        
        vm.prank(depositor);
        escrow.payDeposit(contractId);
        
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore - totalRequired);
        assertEq(usdc.balanceOf(address(escrow)), escrowBalanceBefore + totalRequired);
        
        DepositEscrow.DepositContract memory contract_ = escrow.getContract(contractId);
        assertEq(uint256(contract_.status), uint256(DepositEscrow.ContractStatus.ACTIVE));
    }
    
    function test_PayDeposit_RevertsIfNotDepositor() public {
        uint256 contractId = _createTestContract();
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.OnlyDepositorCanPay.selector);
        escrow.payDeposit(contractId);
    }
    
    function test_PayDeposit_RevertsIfAlreadyPaid() public {
        uint256 contractId = _createTestContract();
        
        vm.prank(depositor);
        escrow.payDeposit(contractId);
        
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.InvalidStatus.selector);
        escrow.payDeposit(contractId);
    }
    
    function test_PayDeposit_RevertsIfContractDoesNotExist() public {
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.ContractDoesNotExist.selector);
        escrow.payDeposit(999);
    }
    
    function test_PayDeposit_RevertsIfInsufficientBalance() public {
        address poorDepositor = address(999);
        
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        vm.prank(beneficiary);
        escrow.createContract(poorDepositor, DEPOSIT_AMOUNT, start, end);
        
        usdc.mint(poorDepositor, 100e6);
        
        vm.prank(poorDepositor);
        usdc.approve(address(escrow), type(uint256).max);
        
        vm.prank(poorDepositor);
        vm.expectRevert();
        escrow.payDeposit(2);
    }
    
    function test_PayDeposit_RevertsIfInsufficientAllowance() public {
        address newDepositor = address(888);
        usdc.mint(newDepositor, 10000e6);
        
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        vm.prank(beneficiary);
        escrow.createContract(newDepositor, DEPOSIT_AMOUNT, start, end);
        
        vm.prank(newDepositor);
        usdc.approve(address(escrow), 100e6);
        
        vm.prank(newDepositor);
        vm.expectRevert();
        escrow.payDeposit(2);
    }
    
    function _createAndPayContract() internal returns (uint256) {
        uint256 contractId = _createTestContract();
        
        vm.prank(depositor);
        escrow.payDeposit(contractId);
        
        return contractId;
    }

    function _createPayAndEndContract() internal returns (uint256) {
        uint256 contractId = _createAndPayContract();
        
        DepositEscrow.DepositContract memory contract_ = escrow.getContract(contractId);
        vm.warp(contract_.contractEnd + 1);
        
        return contractId;
    }
    
    function test_ConfirmCleanExit_Success() public {
        uint256 contractId = _createAndPayContract();
        
        DepositEscrow.DepositContract memory contract_ = escrow.getContract(contractId);
        vm.warp(contract_.contractEnd + 1);
        
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        
        vm.prank(beneficiary);
        escrow.confirmCleanExit(contractId);
        
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore + DEPOSIT_AMOUNT);
        
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

    // =============================================================================
    // DISPUTE TESTS
    // =============================================================================

    function _createAndRaiseDispute() internal returns (uint256) {
        uint256 contractId = _createPayAndEndContract();
        
        vm.prank(beneficiary);
        escrow.raiseDispute(contractId, 300e6, "QmEvidence123");
        
        return contractId;
    }

    function test_RaiseDispute_Success() public {
        uint256 contractId = _createPayAndEndContract();
        
        uint256 claimedAmount = 300e6;
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

    function test_RaiseDispute_RevertsIfNotBeneficiary() public {
        uint256 contractId = _createPayAndEndContract();
        
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.OnlyBeneficiaryCanRaiseDispute.selector);
        escrow.raiseDispute(contractId, 300e6, "QmTest");
    }

    function test_RaiseDispute_RevertsIfContractDoesNotExist() public {
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.ContractDoesNotExist.selector);
        escrow.raiseDispute(999, 300e6, "QmTest");
    }

    function test_RaiseDispute_RevertsIfNotActive() public {
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        
        vm.prank(beneficiary);
        escrow.createContract(depositor, DEPOSIT_AMOUNT, start, end);
        
        vm.warp(end + 1);
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.InvalidStatus.selector);
        escrow.raiseDispute(1, 300e6, "QmTest");
    }

    function test_RaiseDispute_RevertsIfBeforeContractEnd() public {
        uint256 contractId = _createAndPayContract();
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.ContractPeriodNotEnded.selector);
        escrow.raiseDispute(contractId, 300e6, "QmTest");
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
        
        uint256 amountToBeneficiary = 300e6;
        uint256 amountToDepositor = DEPOSIT_AMOUNT - amountToBeneficiary;
        
        uint256 beneficiaryBalanceBefore = usdc.balanceOf(beneficiary);
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        
        vm.prank(resolver);
        escrow.makeResolverDecision(contractId, amountToBeneficiary);
        
        assertEq(usdc.balanceOf(beneficiary), beneficiaryBalanceBefore + amountToBeneficiary);
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore + amountToDepositor);
        
        DepositEscrow.DepositContract memory contract_ = escrow.getContract(contractId);
        assertEq(uint256(contract_.status), uint256(DepositEscrow.ContractStatus.RESOLVED));
    }

    function test_MakeResolverDecision_FullRefundToDepositor() public {
        uint256 contractId = _createAndRaiseDispute();
        
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        uint256 beneficiaryBalanceBefore = usdc.balanceOf(beneficiary);
        
        vm.prank(resolver);
        escrow.makeResolverDecision(contractId, 0);
        
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore + DEPOSIT_AMOUNT);
        assertEq(usdc.balanceOf(beneficiary), beneficiaryBalanceBefore);
    }

    function test_MakeResolverDecision_FullAmountToBeneficiary() public {
        uint256 contractId = _createAndRaiseDispute();
        
        uint256 beneficiaryBalanceBefore = usdc.balanceOf(beneficiary);
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        
        vm.prank(resolver);
        escrow.makeResolverDecision(contractId, DEPOSIT_AMOUNT);
        
        assertEq(usdc.balanceOf(beneficiary), beneficiaryBalanceBefore + DEPOSIT_AMOUNT);
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore);
    }

    function test_MakeResolverDecision_Split5050() public {
        uint256 contractId = _createAndRaiseDispute();
        
        uint256 half = DEPOSIT_AMOUNT / 2;
        
        uint256 beneficiaryBalanceBefore = usdc.balanceOf(beneficiary);
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        
        vm.prank(resolver);
        escrow.makeResolverDecision(contractId, half);
        
        assertEq(usdc.balanceOf(beneficiary), beneficiaryBalanceBefore + half);
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore + half);
    }

    function test_MakeResolverDecision_RevertsIfNotResolver() public {
        uint256 contractId = _createAndRaiseDispute();
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.OnlyResolverCanDecide.selector);
        escrow.makeResolverDecision(contractId, 300e6);
    }

    function test_MakeResolverDecision_RevertsIfContractDoesNotExist() public {
        vm.prank(resolver);
        vm.expectRevert(DepositEscrow.ContractDoesNotExist.selector);
        escrow.makeResolverDecision(999, 300e6);
    }

    function test_MakeResolverDecision_RevertsIfNotDisputed() public {
        uint256 contractId = _createPayAndEndContract();
        
        vm.prank(resolver);
        vm.expectRevert(DepositEscrow.InvalidStatus.selector);
        escrow.makeResolverDecision(contractId, 300e6);
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
        
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        
        escrow.resolveDisputeByTimeout(contractId);
        
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore + DEPOSIT_AMOUNT);
        
        DepositEscrow.DepositContract memory contract_ = escrow.getContract(contractId);
        assertEq(uint256(contract_.status), uint256(DepositEscrow.ContractStatus.RESOLVED));
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