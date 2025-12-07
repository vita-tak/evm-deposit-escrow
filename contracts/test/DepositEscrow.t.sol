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
}