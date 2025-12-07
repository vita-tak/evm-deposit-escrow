// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DepositEscrow is ReentrancyGuard, Ownable {

    error DepositMustBeGreaterThanZero();
    error EndMustBeAfterStart();
    error InvalidDepositorAddress();
    error ContractDoesNotExist();
    error OnlyDepositorCanPay();
    error InvalidStatus();
    error IncorrectAmount();
    error OnlyBeneficiaryCanConfirm();
    error ContractPeriodNotEnded();
    error TransferFailed();

    enum ContractStatus {
        WAITING_FOR_DEPOSIT,
        ACTIVE,
        COMPLETED,
        DISPUTED,
        RESOLVED
    }

    struct DepositContract {
        address depositor;       
        ContractStatus status;   
        address beneficiary;    
        uint256 id;             
        uint256 depositAmount;  
        uint256 contractStart;  
        uint256 contractEnd;     
        uint256 autoReleaseTime;
        }

    mapping(uint256 => DepositContract) public contracts;
    uint256 public nextContractId;
    address public resolver;
    uint256 public platformFee;

    uint256 public constant GRACE_PERIOD = 7 days;

    event ContractCreated(
        uint256 indexed contractId,
        address indexed depositor,
        address indexed beneficiary,
        uint256 depositAmount,
        uint256 contractEnd
    );

    event DepositPaid(
        uint256 indexed contractId,
        address indexed depositor,
        uint256 amount
    );

    event CleanExitConfirmed(
        uint256 indexed contractId,
        address indexed beneficiary
    );

    constructor(address _resolver, uint256 _platformFee) Ownable(msg.sender) {
        resolver = _resolver;
        platformFee = _platformFee;
        nextContractId = 1;
    }

    function createContract(
        address _depositor,
        uint256 _depositAmount,
        uint256 _contractStart,
        uint256 _contractEnd
    ) public {
        if (_depositAmount == 0) revert DepositMustBeGreaterThanZero();
        if (_contractEnd <= _contractStart) revert EndMustBeAfterStart();
        if (_depositor == address(0)) revert InvalidDepositorAddress();

        uint256 contractId = nextContractId;
        uint256 autoReleaseTime = _contractEnd + GRACE_PERIOD;
    
    contracts[contractId] = DepositContract({
        depositor: _depositor,
        status: ContractStatus.WAITING_FOR_DEPOSIT,
        beneficiary: msg.sender, 
        id: contractId,
        depositAmount: _depositAmount,
        contractStart: _contractStart,
        contractEnd: _contractEnd,
        autoReleaseTime: autoReleaseTime
    });

    emit ContractCreated(
        contractId,
        _depositor,
        msg.sender,
        _depositAmount,
        _contractEnd
    );
    
    unchecked {
        nextContractId = contractId + 1;
        }
    }

    function payDeposit(uint256 _contractId) public payable nonReentrant {
        DepositContract storage depositContract = contracts[_contractId];
        
        if (depositContract.id == 0) revert ContractDoesNotExist();
        if (depositContract.depositor != msg.sender) revert OnlyDepositorCanPay();
        if (depositContract.status != ContractStatus.WAITING_FOR_DEPOSIT) revert InvalidStatus();
        
        uint256 fee = (depositContract.depositAmount * platformFee) / 10000;
        uint256 totalRequired = depositContract.depositAmount + fee;
        
        if (msg.value != totalRequired) revert IncorrectAmount();
        
        depositContract.status = ContractStatus.ACTIVE;
        
        emit DepositPaid(_contractId, msg.sender, msg.value);
    }

    function confirmCleanExit(uint256 _contractId) public nonReentrant {
        DepositContract storage depositContract = contracts[_contractId];

        if (depositContract.id == 0) revert ContractDoesNotExist();
        if (depositContract.beneficiary != msg.sender) revert OnlyBeneficiaryCanConfirm();
        if (depositContract.status != ContractStatus.ACTIVE) revert InvalidStatus();
        if (block.timestamp < depositContract.contractEnd) revert ContractPeriodNotEnded();  
    
        (bool success, ) = depositContract.depositor.call{value: depositContract.depositAmount}("");
        if (!success) revert TransferFailed();
    
        depositContract.status = ContractStatus.COMPLETED;
        
        emit CleanExitConfirmed(_contractId, msg.sender);
    }

    function getContract(uint256 _contractId) public view returns (DepositContract memory) {
        if (contracts[_contractId].id == 0) revert ContractDoesNotExist();
        return contracts[_contractId];
    }
}
