// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {DepositEscrow} from "../src/DepositEscrow.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract ChainlinkAutomationTest is Test {
    DepositEscrow public escrow;
    ERC20Mock public usdc;
    
    address public owner;
    address public beneficiary;
    address public depositor;
    address public resolver;
    address public forwarder;
    
    uint256 constant PLATFORM_FEE = 100;
    uint256 constant DEPOSIT_AMOUNT = 1000e6;
    
    event AutoReleaseExecuted(
        uint256 indexed depositId,
        address indexed depositor,
        uint256 amount
    );
    
    event DisputeResolvedByTimeout(
        uint256 indexed depositId,
        address indexed depositor,
        uint256 amount
    );
    
    event ForwarderUpdated(
        address indexed oldForwarder,
        address indexed newForwarder
    );
    
    function setUp() public {
        owner = address(this);
        beneficiary = makeAddr("beneficiary");
        depositor = makeAddr("depositor");
        resolver = makeAddr("resolver");
        forwarder = makeAddr("forwarder");
        
        usdc = new ERC20Mock();
        escrow = new DepositEscrow(resolver, PLATFORM_FEE, address(usdc), resolver);
        
        usdc.mint(depositor, 10000e6);
        escrow.setForwarder(forwarder);
    }

    function _createAndFundDeposit() internal returns (uint256) {
        uint256 depositId = escrow.nextDepositId();
        
        vm.prank(beneficiary);
        escrow.createDeposit(
            depositor,
            DEPOSIT_AMOUNT,
            block.timestamp,
            block.timestamp + 30 days
        );
        
        vm.startPrank(depositor);
        usdc.approve(address(escrow), DEPOSIT_AMOUNT + (DEPOSIT_AMOUNT * PLATFORM_FEE / 10000));
        escrow.payDeposit(depositId);
        vm.stopPrank();
        
        return depositId;
    }
    
    function test_SetForwarder_Success() public {
        address newForwarder = makeAddr("newForwarder");
        
        vm.expectEmit(true, true, false, false);
        emit ForwarderUpdated(forwarder, newForwarder);
        
        escrow.setForwarder(newForwarder);
        
        assertEq(escrow.forwarder(), newForwarder);
    }
    
    function test_SetForwarder_RevertsIfNotOwner() public {
        address newForwarder = makeAddr("newForwarder");
        
        vm.prank(beneficiary);
        vm.expectRevert();
        escrow.setForwarder(newForwarder);
    }
    
    function test_CheckUpkeep_ReturnsFalseWhenNoDeposits() public view {
        (bool upkeepNeeded, bytes memory performData) = escrow.checkUpkeep("");
        
        assertFalse(upkeepNeeded);
        assertEq(performData.length, 0);
    }
    
    function test_CheckUpkeep_ReturnsFalseBeforeAutoReleaseTime() public {
        _createAndFundDeposit();
        
        (bool upkeepNeeded, ) = escrow.checkUpkeep("");
        assertFalse(upkeepNeeded);
        
        vm.warp(block.timestamp + 30 days + 7 days - 1);
        (bool upkeepNeeded2, ) = escrow.checkUpkeep("");
        assertFalse(upkeepNeeded2);
    }
    
    function test_CheckUpkeep_ReturnsFalseForCompletedDeposit() public {
        uint256 depositId = _createAndFundDeposit();
        
        vm.warp(block.timestamp + 30 days);
        vm.prank(beneficiary);
        escrow.confirmCleanExit(depositId);
        
        vm.warp(block.timestamp + 7 days);
        (bool upkeepNeeded, ) = escrow.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }
    
    function test_CheckUpkeep_ReturnsTrueForAutoRelease() public {
        uint256 depositId = _createAndFundDeposit();
        
        vm.warp(block.timestamp + 37 days);
        
        (bool upkeepNeeded, bytes memory performData) = escrow.checkUpkeep("");
        
        assertTrue(upkeepNeeded);
        
        (uint256 returnedId, DepositEscrow.ActionType action) = abi.decode(
            performData,
            (uint256, DepositEscrow.ActionType)
        );
        
        assertEq(returnedId, depositId);
        assertEq(uint8(action), uint8(DepositEscrow.ActionType.AUTO_RELEASE));
    }
    
    function test_CheckUpkeep_ReturnsFirstDepositNeedingAutoRelease() public {
        uint256 depositId1 = _createAndFundDeposit();
        uint256 depositId2 = _createAndFundDeposit();
        uint256 depositId3 = _createAndFundDeposit();
        
        vm.warp(block.timestamp + 30 days);
        vm.startPrank(beneficiary);
        escrow.confirmCleanExit(depositId1);
        escrow.confirmCleanExit(depositId3);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 7 days);
        
        (bool upkeepNeeded, bytes memory performData) = escrow.checkUpkeep("");
        
        assertTrue(upkeepNeeded);
        
        (uint256 returnedId, ) = abi.decode(performData, (uint256, DepositEscrow.ActionType));
        assertEq(returnedId, depositId2);
    }
    
    function test_CheckUpkeep_ReturnsTrueForDisputeTimeout() public {
        uint256 depositId = _createAndFundDeposit();
        
        vm.warp(block.timestamp + 31 days);
        vm.prank(beneficiary);
        escrow.raiseDispute(depositId, 500e6, "ipfs://evidence");
        
        (bool upkeepNeeded, ) = escrow.checkUpkeep("");
        assertFalse(upkeepNeeded);
        
        vm.warp(block.timestamp + 14 days);
        
        (bool upkeepNeeded2, bytes memory performData) = escrow.checkUpkeep("");
        
        assertTrue(upkeepNeeded2);
        
        (uint256 returnedId, DepositEscrow.ActionType action) = abi.decode(
            performData,
            (uint256, DepositEscrow.ActionType)
        );
        
        assertEq(returnedId, depositId);
        assertEq(uint8(action), uint8(DepositEscrow.ActionType.DISPUTE_TIMEOUT));
    }
    
    function test_PerformUpkeep_AutoRelease_Success() public {
        uint256 depositId = _createAndFundDeposit();
        
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        
        vm.warp(block.timestamp + 37 days);
        
        (, bytes memory performData) = escrow.checkUpkeep("");
        
        vm.expectEmit(true, true, false, true);
        emit AutoReleaseExecuted(depositId, depositor, DEPOSIT_AMOUNT);
        
        vm.prank(forwarder);
        escrow.performUpkeep(performData);
        
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore + DEPOSIT_AMOUNT);
        
        DepositEscrow.Deposit memory depositData = escrow.getDeposit(depositId);
        assertEq(uint8(depositData.status), uint8(DepositEscrow.DepositStatus.COMPLETED));
    }
    
    function test_PerformUpkeep_AutoRelease_RevertsIfNotForwarder() public {
        _createAndFundDeposit();
        
        vm.warp(block.timestamp + 37 days);
        (, bytes memory performData) = escrow.checkUpkeep("");
        
        vm.prank(beneficiary);
        vm.expectRevert(DepositEscrow.OnlyForwarder.selector);
        escrow.performUpkeep(performData);
    }
    
    function test_PerformUpkeep_AutoRelease_RevertsIfTooEarly() public {
        uint256 depositId = _createAndFundDeposit();
        
        bytes memory performData = abi.encode(depositId, DepositEscrow.ActionType.AUTO_RELEASE);
        
        vm.warp(block.timestamp + 36 days);
        
        vm.prank(forwarder);
        vm.expectRevert(DepositEscrow.TooEarlyForAutoRelease.selector);
        escrow.performUpkeep(performData);
    }
    
    function test_PerformUpkeep_DisputeTimeout_Success() public {
        uint256 depositId = _createAndFundDeposit();
        
        vm.warp(block.timestamp + 31 days);
        vm.prank(beneficiary);
        escrow.raiseDispute(depositId, 500e6, "ipfs://evidence");
        
        uint256 depositorBalanceBefore = usdc.balanceOf(depositor);
        
        vm.warp(block.timestamp + 14 days);
        
        (, bytes memory performData) = escrow.checkUpkeep("");
        
        vm.expectEmit(true, true, false, true);
        emit DisputeResolvedByTimeout(depositId, depositor, DEPOSIT_AMOUNT);
        
        vm.prank(forwarder);
        escrow.performUpkeep(performData);
        
        assertEq(usdc.balanceOf(depositor), depositorBalanceBefore + DEPOSIT_AMOUNT);
        
        DepositEscrow.Deposit memory depositData = escrow.getDeposit(depositId);
        assertEq(uint8(depositData.status), uint8(DepositEscrow.DepositStatus.RESOLVED));
    }
    
    function test_PerformUpkeep_DisputeTimeout_RevertsIfTooEarly() public {
        uint256 depositId = _createAndFundDeposit();
        
        vm.warp(block.timestamp + 31 days);
        vm.prank(beneficiary);
        escrow.raiseDispute(depositId, 500e6, "ipfs://evidence");
        
        bytes memory performData = abi.encode(depositId, DepositEscrow.ActionType.DISPUTE_TIMEOUT);
        
        vm.warp(block.timestamp + 13 days);
        
        vm.prank(forwarder);
        vm.expectRevert(DepositEscrow.DisputeStillActive.selector);
        escrow.performUpkeep(performData);
    }
    
    function test_CheckUpkeep_SkipsNonExistentDeposits() public view {
        (bool upkeepNeeded, ) = escrow.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }
    
    function test_PerformUpkeep_AutoRelease_ExactlyAtAutoReleaseTime() public {
        uint256 depositId = _createAndFundDeposit();
        
        vm.warp(block.timestamp + 37 days);
        
        (bool upkeepNeeded, bytes memory performData) = escrow.checkUpkeep("");
        assertTrue(upkeepNeeded);
        
        vm.prank(forwarder);
        escrow.performUpkeep(performData);
        
        DepositEscrow.Deposit memory depositData = escrow.getDeposit(depositId);
        assertEq(uint8(depositData.status), uint8(DepositEscrow.DepositStatus.COMPLETED));
    }
}
