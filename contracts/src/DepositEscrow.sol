// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

contract DepositEscrow is AutomationCompatibleInterface, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    enum ActionType {
        AUTO_RELEASE,
        DISPUTE_TIMEOUT
    }

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
    error OnlyBeneficiaryCanRaiseDispute();
    error AmountExceedsDeposit();
    error OnlyDepositorCanRespond(); 
    error AlreadyResponded();
    error OnlyResolverCanDecide();
    error DisputeStillActive();
    error OnlyForwarder();
    error TooEarlyForAutoRelease();

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

    struct Dispute {
        uint256 claimedAmount;
        string evidenceHash;
        string responseHash;
        bool depositorResponded; 
        uint256 disputeStartTime;
    }

    mapping(uint256 => DepositContract) public contracts;
    mapping(uint256 => Dispute) public disputes;
    uint256 public nextContractId;
    address public resolver;
    uint256 public platformFee;
    IERC20 public immutable USDC_TOKEN; 

    uint256[] private activeContractsForAutoRelease;
    uint256[] private disputedContractsForTimeout;

    uint256 public constant GRACE_PERIOD = 7 days;
    uint256 public constant DISPUTE_RESOLUTION_TIME = 14 days;

    address public forwarder;

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

    event DisputeRaised(
        uint256 indexed contractId,
        address indexed beneficiary,
        uint256 claimedAmount,
        string evidenceHash
    );

    event DepositorRespondedToDispute(
        uint256 indexed contractId,
        address indexed depositor,
        string responseHash
    );

    event ResolverDecisionMade(
        uint256 indexed contractId,
        address indexed resolver,
        uint256 amountToDepositor,
        uint256 amountToBeneficiary
    );

    event DisputeResolvedByTimeout(
        uint256 indexed contractId,
        address indexed depositor,
        uint256 amount
    );

    event AutoReleaseExecuted(
        uint256 indexed contractId,
        address indexed depositor,
        uint256 amount
    );

    event ForwarderUpdated(
        address indexed oldForwarder,
        address indexed newForwarder
    );

    modifier onlyForwarder() {
        if (msg.sender != forwarder) revert OnlyForwarder();
        _;
    }

    constructor(address _resolver, uint256 _platformFee, address _usdcToken) Ownable(msg.sender) {
        resolver = _resolver;
        platformFee = _platformFee;
        nextContractId = 1;
        USDC_TOKEN = IERC20(_usdcToken);
        forwarder = address(0);
    }

    function createContract(address _depositor, uint256 _depositAmount, uint256 _contractStart, uint256 _contractEnd) public {
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

    function payDeposit(uint256 _contractId) public nonReentrant {
        DepositContract storage depositContract = contracts[_contractId];
        
        if (depositContract.id == 0) revert ContractDoesNotExist();
        if (depositContract.depositor != msg.sender) revert OnlyDepositorCanPay();
        if (depositContract.status != ContractStatus.WAITING_FOR_DEPOSIT) revert InvalidStatus();
        
        uint256 fee = (depositContract.depositAmount * platformFee) / 10000;
        uint256 totalRequired = depositContract.depositAmount + fee;

        USDC_TOKEN.safeTransferFrom(msg.sender, address(this), totalRequired);
        
        depositContract.status = ContractStatus.ACTIVE;

        activeContractsForAutoRelease.push(_contractId);
        
        emit DepositPaid(_contractId, msg.sender, totalRequired);
    }

    function getContract(uint256 _contractId) public view returns (DepositContract memory) {
        if (contracts[_contractId].id == 0) revert ContractDoesNotExist();
        return contracts[_contractId];
    }

    function raiseDispute(
        uint256 _contractId, 
        uint256 _claimedAmount, 
        string memory _evidenceHash
    ) public {
        DepositContract storage depositContract = contracts[_contractId];

        if (depositContract.id == 0) revert ContractDoesNotExist();
        if (_claimedAmount == 0) revert DepositMustBeGreaterThanZero(); 
        if (depositContract.beneficiary != msg.sender) revert OnlyBeneficiaryCanRaiseDispute();
        if (depositContract.status != ContractStatus.ACTIVE) revert InvalidStatus();              
        if (block.timestamp < depositContract.contractEnd) revert ContractPeriodNotEnded();       
        if (_claimedAmount > depositContract.depositAmount) revert AmountExceedsDeposit();            
        
        disputes[_contractId] = Dispute({
            claimedAmount: _claimedAmount,
            evidenceHash: _evidenceHash,
            responseHash: "",    
            depositorResponded: false,
            disputeStartTime: block.timestamp  
        });
        
        depositContract.status = ContractStatus.DISPUTED; 

        _removeFromArray(activeContractsForAutoRelease, _contractId);
        disputedContractsForTimeout.push(_contractId);
        
        emit DisputeRaised(_contractId, msg.sender, _claimedAmount, _evidenceHash);
    }

    function respondToDispute(uint256 _contractId, string memory _responseHash) public {
        DepositContract storage depositContract = contracts[_contractId];

        if (depositContract.id == 0) revert ContractDoesNotExist();
        if (msg.sender != depositContract.depositor) revert OnlyDepositorCanRespond();
        if (depositContract.status != ContractStatus.DISPUTED) revert InvalidStatus();
        if (disputes[_contractId].depositorResponded) revert AlreadyResponded();
        
        disputes[_contractId].responseHash = _responseHash;
        disputes[_contractId].depositorResponded = true;
    
        emit DepositorRespondedToDispute(_contractId, msg.sender, _responseHash);
    }

    function makeResolverDecision(uint256 _contractId, uint256 _amountToBeneficiary) public nonReentrant {
        DepositContract storage depositContract = contracts[_contractId];

        if (resolver != msg.sender) revert OnlyResolverCanDecide();
        if (depositContract.id == 0) revert ContractDoesNotExist();
        if (depositContract.status != ContractStatus.DISPUTED) revert InvalidStatus(); 
        if (_amountToBeneficiary > depositContract.depositAmount) revert AmountExceedsDeposit();
        
        USDC_TOKEN.safeTransfer(depositContract.beneficiary, _amountToBeneficiary);

        uint256 amountToDepositor = depositContract.depositAmount - _amountToBeneficiary;

        USDC_TOKEN.safeTransfer(depositContract.depositor, amountToDepositor);
        
        depositContract.status = ContractStatus.RESOLVED;
        _removeFromArray(disputedContractsForTimeout, _contractId);
        
        emit ResolverDecisionMade(_contractId, msg.sender, amountToDepositor, _amountToBeneficiary);
    }

    function resolveDisputeByTimeout(uint256 _contractId) public nonReentrant {
        DepositContract storage depositContract = contracts[_contractId];

        if (block.timestamp < disputes[_contractId].disputeStartTime + DISPUTE_RESOLUTION_TIME) {
            revert DisputeStillActive();
        }
        
        _resolveDisputeToDepositor(_contractId);
        _removeFromArray(disputedContractsForTimeout, _contractId);
        
        emit DisputeResolvedByTimeout(_contractId, depositContract.depositor, depositContract.depositAmount);
    }

    function confirmCleanExit(uint256 _contractId) public nonReentrant {
        DepositContract storage depositContract = contracts[_contractId];

        if (depositContract.beneficiary != msg.sender) revert OnlyBeneficiaryCanConfirm();
        if (block.timestamp < depositContract.contractEnd) revert ContractPeriodNotEnded();
        
        _releaseDepositToDepositor(_contractId);
        _removeFromArray(activeContractsForAutoRelease, _contractId);
        
        emit CleanExitConfirmed(_contractId, msg.sender);
    }

    function _releaseDepositToDepositor(uint256 _contractId) internal {
        DepositContract storage depositContract = contracts[_contractId];
        
        if (depositContract.id == 0) revert ContractDoesNotExist();
        if (depositContract.status != ContractStatus.ACTIVE) revert InvalidStatus();
        
        USDC_TOKEN.safeTransfer(depositContract.depositor, depositContract.depositAmount);
        
        depositContract.status = ContractStatus.COMPLETED;
    }

    function _resolveDisputeToDepositor(uint256 _contractId) internal {
        DepositContract storage depositContract = contracts[_contractId];
        
        if (depositContract.id == 0) revert ContractDoesNotExist();
        if (depositContract.status != ContractStatus.DISPUTED) revert InvalidStatus();
        
        USDC_TOKEN.safeTransfer(depositContract.depositor, depositContract.depositAmount);
        
        depositContract.status = ContractStatus.RESOLVED;
    }

    function setForwarder(address _forwarder) external onlyOwner {
        address oldForwarder = forwarder;
        forwarder = _forwarder;
        emit ForwarderUpdated(oldForwarder, _forwarder);
    }

    function checkUpkeep(bytes calldata)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        for (uint256 i = 0; i < activeContractsForAutoRelease.length; i++) {
            uint256 contractId = activeContractsForAutoRelease[i];
            DepositContract memory c = contracts[contractId];
            
            if (block.timestamp >= c.autoReleaseTime) {
                return (true, abi.encode(contractId, ActionType.AUTO_RELEASE));
            }
        }
        for (uint256 i = 0; i < disputedContractsForTimeout.length; i++) {
            uint256 contractId = disputedContractsForTimeout[i];
            Dispute memory d = disputes[contractId];
            
            if (block.timestamp >= d.disputeStartTime + DISPUTE_RESOLUTION_TIME) {
                return (true, abi.encode(contractId, ActionType.DISPUTE_TIMEOUT));
            }
        }
        return (false, "");
    }

    function performUpkeep(bytes calldata performData) external override onlyForwarder nonReentrant {
        (uint256 contractId, ActionType action) = abi.decode(performData, (uint256, ActionType));
        DepositContract storage depositContract = contracts[contractId]; 

        if (action == ActionType.AUTO_RELEASE) {
            if (block.timestamp < depositContract.autoReleaseTime) {
                revert TooEarlyForAutoRelease();
            }
            
            _releaseDepositToDepositor(contractId);
            _removeFromArray(activeContractsForAutoRelease, contractId);
            
            emit AutoReleaseExecuted(contractId, depositContract.depositor, depositContract.depositAmount);
            
        } else if (action == ActionType.DISPUTE_TIMEOUT) {
            if (block.timestamp < disputes[contractId].disputeStartTime + DISPUTE_RESOLUTION_TIME) {
                revert DisputeStillActive();
            }

            _resolveDisputeToDepositor(contractId);
            _removeFromArray(disputedContractsForTimeout, contractId);

            emit DisputeResolvedByTimeout(contractId, depositContract.depositor, depositContract.depositAmount);
        }
    }

    function _removeFromArray(uint256[] storage array, uint256 valueToRemove) private {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == valueToRemove) {
                array[i] = array[array.length - 1];
                array.pop();
                return;
            }
        }
    }
}
