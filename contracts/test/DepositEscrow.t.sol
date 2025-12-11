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
    address public alice = address(4); 
    address public feeRecipient = address(5); 
    
    uint256 public constant PLATFORM_FEE = 100;
    uint256 public constant DEPOSIT_AMOUNT = 1000e6;

    event ResolverUpdated(address indexed oldResolver, address indexed newResolver);
    event FeeRecipientUpdated(address indexed oldFeeRecipient, address indexed newFeeRecipient);
    
    function setUp() public {
        usdc = new ERC20Mock();
        escrow = new DepositEscrow(resolver, PLATFORM_FEE, address(usdc), feeRecipient);
        usdc.mint(depositor, 10000e6);
        vm.prank(depositor);
        usdc.approve(address(escrow), type(uint256).max);
    }
    
    function test_CreateDeposit_Success() public {
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        
        vm.prank(beneficiary);
        escrow.createDeposit(depositor, DEPOSIT_AMOUNT, start, end);
        
        DepositEscrow.Deposit memory deposit = escrow.getDeposit(1);
        
        assertEq(deposit.id, 1);
        assertEq(deposit.depositor, depositor);
        assertEq(deposit.beneficiary, beneficiary);
        assertEq(deposit.depositAmount, DEPOSIT_AMOUNT);
        assertEq(uint256(deposit.status), uint256(DepositEscrow.DepositStatus.WAITING_FOR_DEPOSIT));
        assertEq(deposit.autoReleaseTime, end + 7 days);
    }
    
    function test_CreateDeposit_RevertsIfDepositIsZero() public {
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.DepositMustBeGreaterThanZero.selector);
        escrow.createDeposit(depositor, 0, start, end);
    }
    
    function test_CreateDeposit_RevertsIfEndBeforeStart() public {
        uint256 start = block.timestamp + 30 days;
        uint256 end = start - 1 days;
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.EndMustBeAfterStart.selector);
        escrow.createDeposit(depositor, DEPOSIT_AMOUNT, start, end);
    }
    
    function test_CreateDeposit_RevertsIfDepositorIsZero() public {
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.InvalidDepositorAddress.selector);
        escrow.createDeposit(address(0), DEPOSIT_AMOUNT, start, end);
    }
    
    function _createTestDeposit() internal returns (uint256) {
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        
        vm.prank(beneficiary);
        escrow.createDeposit(depositor, DEPOSIT_AMOUNT, start, end);
        
        return 1;
    }
    
    function test_PayDeposit_Success() public {
        uint256 depositId = _createTestDeposit();
        
        uint256 fee = (DEPOSIT_AMOUNT * PLATFORM_FEE) / 10000;
        uint256 totalRequired = DEPOSIT_AMOUNT + fee;
        
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        uint256 escrowBalanceBefore = usdc.balanceOf(address(escrow));
        
        vm.prank(depositor);
        escrow.payDeposit(depositId);
        
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore - totalRequired);
        assertEq(usdc.balanceOf(address(escrow)), escrowBalanceBefore + DEPOSIT_AMOUNT);
        assertEq(usdc.balanceOf(feeRecipient), fee);
        
        DepositEscrow.Deposit memory deposit = escrow.getDeposit(depositId);
        assertEq(uint256(deposit.status), uint256(DepositEscrow.DepositStatus.ACTIVE));
    }
    
    function test_PayDeposit_RevertsIfNotDepositor() public {
        uint256 depositId = _createTestDeposit();
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.OnlyDepositorCanPay.selector);
        escrow.payDeposit(depositId);
    }
    
    function test_PayDeposit_RevertsIfAlreadyPaid() public {
        uint256 depositId = _createTestDeposit();
        
        vm.prank(depositor);
        escrow.payDeposit(depositId);
        
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.InvalidStatus.selector);
        escrow.payDeposit(depositId);
    }
    
    function test_PayDeposit_RevertsIfDepositDoesNotExist() public {
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.DepositDoesNotExist.selector);
        escrow.payDeposit(999);
    }
    
    function test_PayDeposit_RevertsIfInsufficientBalance() public {
        address poorDepositor = address(999);
        
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        vm.prank(beneficiary);
        escrow.createDeposit(poorDepositor, DEPOSIT_AMOUNT, start, end);
        
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
        escrow.createDeposit(newDepositor, DEPOSIT_AMOUNT, start, end);
        
        vm.prank(newDepositor);
        usdc.approve(address(escrow), 100e6);
        
        vm.prank(newDepositor);
        vm.expectRevert();
        escrow.payDeposit(2);
    }
    
    function _createAndPayDeposit() internal returns (uint256) {
        uint256 depositId = _createTestDeposit();
        
        vm.prank(depositor);
        escrow.payDeposit(depositId);
        
        return depositId;
    }

    function _createPayAndEndDeposit() internal returns (uint256) {
        uint256 depositId = _createAndPayDeposit();
        
        DepositEscrow.Deposit memory deposit = escrow.getDeposit(depositId);
        vm.warp(deposit.periodEnd + 1);
        
        return depositId;
    }
    
    function test_ConfirmCleanExit_Success() public {
        uint256 depositId = _createAndPayDeposit();
        
        DepositEscrow.Deposit memory deposit = escrow.getDeposit(depositId);
        vm.warp(deposit.periodEnd + 1);
        
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        
        vm.prank(beneficiary);
        escrow.confirmCleanExit(depositId);
        
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore + DEPOSIT_AMOUNT);
        
        deposit = escrow.getDeposit(depositId);
        assertEq(uint256(deposit.status), uint256(DepositEscrow.DepositStatus.COMPLETED));
    }
    
    function test_ConfirmCleanExit_RevertsIfNotBeneficiary() public {
        uint256 depositId = _createAndPayDeposit();
        
        DepositEscrow.Deposit memory deposit = escrow.getDeposit(depositId);
        vm.warp(deposit.periodEnd + 1);
        
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.OnlyBeneficiaryCanConfirm.selector);
        escrow.confirmCleanExit(depositId);
    }
    
    function test_ConfirmCleanExit_RevertsIfBeforeEnd() public {
        uint256 depositId = _createAndPayDeposit();
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.PeriodNotEnded.selector);
        escrow.confirmCleanExit(depositId);
    }
    
    function test_ConfirmCleanExit_RevertsIfNotActive() public {
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        
        vm.prank(beneficiary);
        escrow.createDeposit(depositor, DEPOSIT_AMOUNT, start, end);
        
        vm.warp(end + 1);
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.InvalidStatus.selector);
        escrow.confirmCleanExit(1);
    }

    function _createAndRaiseDispute() internal returns (uint256) {
        uint256 depositId = _createPayAndEndDeposit();
        
        vm.prank(beneficiary);
        escrow.raiseDispute(depositId, 300e6, "QmEvidence123");
        
        return depositId;
    }

    function test_RaiseDispute_Success() public {
        uint256 depositId = _createPayAndEndDeposit();
        
        uint256 claimedAmount = 300e6;
        string memory evidenceHash = "QmTest123";
        
        vm.prank(beneficiary);
        escrow.raiseDispute(depositId, claimedAmount, evidenceHash);
        
        DepositEscrow.Deposit memory deposit = escrow.getDeposit(depositId);
        assertEq(uint256(deposit.status), uint256(DepositEscrow.DepositStatus.DISPUTED));
        
        (uint256 claimed, string memory evidence, , bool responded, uint256 startTime) = escrow.disputes(depositId);
        assertEq(claimed, claimedAmount);
        assertEq(evidence, evidenceHash);
        assertEq(responded, false);
        assertEq(startTime, block.timestamp);
    }

    function test_RaiseDispute_RevertsIfNotBeneficiary() public {
        uint256 depositId = _createPayAndEndDeposit();
        
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.OnlyBeneficiaryCanRaiseDispute.selector);
        escrow.raiseDispute(depositId, 300e6, "QmTest");
    }

    function test_RaiseDispute_RevertsIfDepositDoesNotExist() public {
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.DepositDoesNotExist.selector);
        escrow.raiseDispute(999, 300e6, "QmTest");
    }

    function test_RaiseDispute_RevertsIfNotActive() public {
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        
        vm.prank(beneficiary);
        escrow.createDeposit(depositor, DEPOSIT_AMOUNT, start, end);
        
        vm.warp(end + 1);
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.InvalidStatus.selector);
        escrow.raiseDispute(1, 300e6, "QmTest");
    }

    function test_RaiseDispute_RevertsIfBeforePeriodEnd() public {
        uint256 depositId = _createAndPayDeposit();
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.PeriodNotEnded.selector);
        escrow.raiseDispute(depositId, 300e6, "QmTest");
    }

    function test_RaiseDispute_RevertsIfClaimedAmountIsZero() public {
        uint256 depositId = _createPayAndEndDeposit();
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.DepositMustBeGreaterThanZero.selector);
        escrow.raiseDispute(depositId, 0, "QmTest");
    }

    function test_RaiseDispute_RevertsIfClaimedAmountExceedsDeposit() public {
        uint256 depositId = _createPayAndEndDeposit();
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.AmountExceedsDeposit.selector);
        escrow.raiseDispute(depositId, DEPOSIT_AMOUNT + 1, "QmTest");
    }

    function test_RespondToDispute_Success() public {
        uint256 depositId = _createAndRaiseDispute();
        
        string memory responseHash = "QmResponse123";
        
        vm.prank(depositor);
        escrow.respondToDispute(depositId, responseHash);
        
        (, , string memory response, bool responded, ) = escrow.disputes(depositId);
        assertEq(response, responseHash);
        assertEq(responded, true);
    }

    function test_RespondToDispute_RevertsIfNotDepositor() public {
        uint256 depositId = _createAndRaiseDispute();
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.OnlyDepositorCanRespond.selector);
        escrow.respondToDispute(depositId, "QmResponse");
    }

    function test_RespondToDispute_RevertsIfDepositDoesNotExist() public {
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.DepositDoesNotExist.selector);
        escrow.respondToDispute(999, "QmResponse");
    }

    function test_RespondToDispute_RevertsIfNotDisputed() public {
        uint256 depositId = _createPayAndEndDeposit();
        
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.InvalidStatus.selector);
        escrow.respondToDispute(depositId, "QmResponse");
    }

    function test_RespondToDispute_RevertsIfAlreadyResponded() public {
        uint256 depositId = _createAndRaiseDispute();
        
        vm.prank(depositor);
        escrow.respondToDispute(depositId, "QmResponse1");
        
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.AlreadyResponded.selector);
        escrow.respondToDispute(depositId, "QmResponse2");
    }

    function test_MakeResolverDecision_Success() public {
        uint256 depositId = _createAndRaiseDispute();
        
        uint256 amountToBeneficiary = 300e6;
        uint256 amountToDepositor = DEPOSIT_AMOUNT - amountToBeneficiary;
        
        uint256 beneficiaryBalanceBefore = usdc.balanceOf(beneficiary);
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        
        vm.prank(resolver);
        escrow.makeResolverDecision(depositId, amountToBeneficiary);
        
        assertEq(usdc.balanceOf(beneficiary), beneficiaryBalanceBefore + amountToBeneficiary);
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore + amountToDepositor);
        
        DepositEscrow.Deposit memory deposit = escrow.getDeposit(depositId);
        assertEq(uint256(deposit.status), uint256(DepositEscrow.DepositStatus.RESOLVED));
    }

    function test_MakeResolverDecision_FullRefundToDepositor() public {
        uint256 depositId = _createAndRaiseDispute();
        
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        uint256 beneficiaryBalanceBefore = usdc.balanceOf(beneficiary);
        
        vm.prank(resolver);
        escrow.makeResolverDecision(depositId, 0);
        
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore + DEPOSIT_AMOUNT);
        assertEq(usdc.balanceOf(beneficiary), beneficiaryBalanceBefore);
    }

    function test_MakeResolverDecision_FullAmountToBeneficiary() public {
        uint256 depositId = _createAndRaiseDispute();
        
        uint256 beneficiaryBalanceBefore = usdc.balanceOf(beneficiary);
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        
        vm.prank(resolver);
        escrow.makeResolverDecision(depositId, DEPOSIT_AMOUNT);
        
        assertEq(usdc.balanceOf(beneficiary), beneficiaryBalanceBefore + DEPOSIT_AMOUNT);
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore);
    }

    function test_MakeResolverDecision_Split5050() public {
        uint256 depositId = _createAndRaiseDispute();
        
        uint256 half = DEPOSIT_AMOUNT / 2;
        
        uint256 beneficiaryBalanceBefore = usdc.balanceOf(beneficiary);
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        
        vm.prank(resolver);
        escrow.makeResolverDecision(depositId, half);
        
        assertEq(usdc.balanceOf(beneficiary), beneficiaryBalanceBefore + half);
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore + half);
    }

    function test_MakeResolverDecision_RevertsIfNotResolver() public {
        uint256 depositId = _createAndRaiseDispute();
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.OnlyResolverCanDecide.selector);
        escrow.makeResolverDecision(depositId, 300e6);
    }

    function test_MakeResolverDecision_RevertsIfDepositDoesNotExist() public {
        vm.prank(resolver);
        vm.expectRevert(DepositEscrow.DepositDoesNotExist.selector);
        escrow.makeResolverDecision(999, 300e6);
    }

    function test_MakeResolverDecision_RevertsIfNotDisputed() public {
        uint256 depositId = _createPayAndEndDeposit();
        
        vm.prank(resolver);
        vm.expectRevert(DepositEscrow.InvalidStatus.selector);
        escrow.makeResolverDecision(depositId, 300e6);
    }

    function test_MakeResolverDecision_RevertsIfAmountExceedsDeposit() public {
        uint256 depositId = _createAndRaiseDispute();
        
        vm.prank(resolver);
        vm.expectRevert(DepositEscrow.AmountExceedsDeposit.selector);
        escrow.makeResolverDecision(depositId, DEPOSIT_AMOUNT + 1);
    }

    function test_ResolveDisputeByTimeout_Success() public {
        uint256 depositId = _createAndRaiseDispute();
        
        vm.warp(block.timestamp + 14 days + 1);
        
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        
        vm.prank(depositor); 
        escrow.resolveDisputeByTimeout(depositId);
        
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore + DEPOSIT_AMOUNT);
        
        DepositEscrow.Deposit memory deposit = escrow.getDeposit(depositId);
        assertEq(uint256(deposit.status), uint256(DepositEscrow.DepositStatus.RESOLVED));
    }

    function test_ResolveDisputeByTimeout_RevertsIfTooEarly() public {
        uint256 depositId = _createAndRaiseDispute();
        
        vm.warp(block.timestamp + 13 days);
        
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.DisputeStillActive.selector);
        escrow.resolveDisputeByTimeout(depositId);
    }

    function test_ResolveDisputeByTimeout_RevertsIfNotDisputed() public {
        uint256 depositId = _createPayAndEndDeposit();
        
        vm.warp(block.timestamp + 14 days + 1);
        
        vm.prank(depositor);
        vm.expectRevert(DepositEscrow.InvalidStatus.selector);
        escrow.resolveDisputeByTimeout(depositId);
    }

    function test_ResolveDisputeByTimeout_RevertsIfDepositDoesNotExist() public {
        vm.warp(block.timestamp + 14 days + 1);
        
        vm.expectRevert(DepositEscrow.DepositDoesNotExist.selector);
        escrow.resolveDisputeByTimeout(999);
    }

    function test_SetResolver_Success() public {
        address newResolver = makeAddr("newResolver");
        
        vm.expectEmit(true, true, false, false);
        emit ResolverUpdated(resolver, newResolver);
        
        escrow.setResolver(newResolver);
        
        assertEq(escrow.resolver(), newResolver);
    }

    function test_SetResolver_RevertsIfNotOwner() public {
        address newResolver = makeAddr("newResolver");
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        escrow.setResolver(newResolver);
    }

    function test_SetResolver_RevertsIfZeroAddress() public {
        vm.expectRevert(DepositEscrow.InvalidResolverAddress.selector);
        escrow.setResolver(address(0));
    }

    function test_SetResolver_RevertsIfContractAddress() public {
        vm.expectRevert(DepositEscrow.InvalidResolverAddress.selector);
        escrow.setResolver(address(escrow));
    }

    function test_SetResolver_RevertsIfUnchanged() public {
        address currentResolver = escrow.resolver();
        
        vm.expectRevert(DepositEscrow.ResolverUnchanged.selector);
        escrow.setResolver(currentResolver);
    }

    function test_SetFeeRecipient_Success() public {
        address newFeeRecipient = makeAddr("newFeeRecipient");
        
        vm.expectEmit(true, true, false, false);
        emit FeeRecipientUpdated(feeRecipient, newFeeRecipient);
        
        escrow.setFeeRecipient(newFeeRecipient);
        
        assertEq(escrow.feeRecipient(), newFeeRecipient);
    }

    function test_SetFeeRecipient_RevertsIfNotOwner() public {
        address newFeeRecipient = makeAddr("newFeeRecipient");
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        escrow.setFeeRecipient(newFeeRecipient);
    }

    function test_SetFeeRecipient_RevertsIfZeroAddress() public {
        vm.expectRevert(DepositEscrow.InvalidFeeRecipientAddress.selector);
        escrow.setFeeRecipient(address(0));
    }

    function test_SetFeeRecipient_RevertsIfContractAddress() public {
        vm.expectRevert(DepositEscrow.InvalidFeeRecipientAddress.selector);
        escrow.setFeeRecipient(address(escrow));
    }

    function test_SetFeeRecipient_RevertsIfUnchanged() public {
        address currentFeeRecipient = escrow.feeRecipient();
        
        vm.expectRevert(DepositEscrow.FeeRecipientUnchanged.selector);
        escrow.setFeeRecipient(currentFeeRecipient);
    }

    function test_RescueTokens_Success() public {
        usdc.mint(address(escrow), 1000e6);
        
        uint256 ownerBalanceBefore = usdc.balanceOf(address(this));
        
        escrow.rescueTokens(address(usdc), 1000e6);
        
        assertEq(usdc.balanceOf(address(this)), ownerBalanceBefore + 1000e6);
        assertEq(usdc.balanceOf(address(escrow)), 0);
    }

    function test_RescueTokens_RevertsIfNotOwner() public {
        usdc.mint(address(escrow), 1000e6);
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        escrow.rescueTokens(address(usdc), 1000e6);
    }

    function test_RescueTokens_RevertsIfZeroAddress() public {
        vm.expectRevert(DepositEscrow.InvalidUSDCAddress.selector);
        escrow.rescueTokens(address(0), 1000e6);
    }

    function test_Pause_Success() public {
        escrow.pause();
        assertTrue(escrow.paused());
    }

    function test_Unpause_Success() public {
        escrow.pause();
        escrow.unpause();
        assertFalse(escrow.paused());
    }

    function test_Pause_RevertsIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        escrow.pause();
    }

    function test_CreateDeposit_RevertsWhenPaused() public {
        escrow.pause();
        
        uint256 start = block.timestamp;
        uint256 end = start + 30 days;
        
        vm.prank(beneficiary);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.createDeposit(depositor, DEPOSIT_AMOUNT, start, end);
    }

    function test_PayDeposit_RevertsWhenPaused() public {
        uint256 depositId = _createTestDeposit();
        
        escrow.pause();
        
        vm.prank(depositor);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.payDeposit(depositId);
    }

    function test_RaiseDispute_RevertsWhenPaused() public {
        uint256 depositId = _createPayAndEndDeposit();
        
        escrow.pause();
        
        vm.prank(beneficiary);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.raiseDispute(depositId, 300e6, "QmTest");
    }

    function test_RespondToDispute_RevertsWhenPaused() public {
        uint256 depositId = _createAndRaiseDispute();
        
        escrow.pause();
        
        vm.prank(depositor);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        escrow.respondToDispute(depositId, "QmResponse");
    }

    function test_ConfirmCleanExit_WorksWhenPaused() public {
        uint256 depositId = _createAndPayDeposit();
        
        DepositEscrow.Deposit memory deposit = escrow.getDeposit(depositId);
        vm.warp(deposit.periodEnd + 1);
        
        escrow.pause();
        
        vm.prank(beneficiary);
        escrow.confirmCleanExit(depositId);
        
        deposit = escrow.getDeposit(depositId);
        assertEq(uint256(deposit.status), uint256(DepositEscrow.DepositStatus.COMPLETED));
    }

    function test_Constructor_RevertsIfFeeTooHigh() public {
        vm.expectRevert(DepositEscrow.FeeTooHigh.selector);
        
        new DepositEscrow(
            resolver,
            1001,
            address(usdc),
            feeRecipient
        );
    }

    function test_Constructor_AcceptsMaxFee() public {
        DepositEscrow newEscrow = new DepositEscrow(resolver,
        1000, 
        address(usdc),
        feeRecipient);   
        assertEq(newEscrow.platformFee(), 1000);      
        }
    }
