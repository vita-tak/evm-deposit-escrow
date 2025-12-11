// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

contract DepositEscrow is AutomationCompatibleInterface, ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    enum ActionType {
        AUTO_RELEASE,
        DISPUTE_TIMEOUT
    }

error AmountExceedsDeposit();
error DepositMustBeGreaterThanZero();
error EndMustBeAfterStart();
error FeeTooHigh();
error IncorrectAmount();

error InvalidDepositorAddress();
error InvalidFeeRecipientAddress();
error InvalidResolverAddress();
error InvalidUSDCAddress();
error ResolverUnchanged();
error FeeRecipientUnchanged();

error AlreadyResponded();
error ContractDoesNotExist();
error ContractPeriodNotEnded();
error DisputeStillActive();
error InvalidStatus();
error TooEarlyForAutoRelease();
error TransferFailed();

error OnlyBeneficiaryCanConfirm();
error OnlyBeneficiaryCanRaiseDispute();
error OnlyDepositorCanPay();
error OnlyDepositorCanRespond();
error OnlyDepositorCanResolveTimeout();
error OnlyForwarder();
error OnlyResolverCanDecide();

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
    address public feeRecipient;
    uint256 public constant MAX_PLATFORM_FEE = 1000;
    IERC20 public immutable USDC_TOKEN;

    uint256[] private activeContractsForAutoRelease;
    uint256[] private disputedContractsForTimeout;

    uint256 public constant GRACE_PERIOD = 7 days;
    uint256 public constant DISPUTE_RESOLUTION_TIME = 14 days;
    uint public constant DISPUTE_EXTENSION_TIME = 4 days;
    uint256 private constant MAX_CHECKS_PER_UPKEEP = 75;

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
        address indexed depositor
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

    event ResolverUpdated(
        address indexed oldResolver,
        address indexed newResolver
    );

    event FeeRecipientUpdated(
        address indexed oldFeeRecipient,
        address indexed newFeeRecipient);

    modifier onlyForwarder() {
        if (msg.sender != forwarder) revert OnlyForwarder();
        _;
    }

    constructor(address _resolver, uint256 _platformFee, address _usdcToken, address _feeRecipient) Ownable(msg.sender) {
        if (_resolver == address(0)) revert InvalidResolverAddress();
        if (_usdcToken == address(0)) revert InvalidUSDCAddress();
        if (_feeRecipient == address(0)) revert InvalidFeeRecipientAddress();
        if (_feeRecipient == address(this)) revert InvalidFeeRecipientAddress();
        if (_resolver == address(this)) revert InvalidResolverAddress();
        if (_platformFee > MAX_PLATFORM_FEE) revert FeeTooHigh();

        resolver = _resolver;
        platformFee = _platformFee;
        nextContractId = 1;
        USDC_TOKEN = IERC20(_usdcToken);
        forwarder = address(0);
        feeRecipient = _feeRecipient;
    }

    function createContract(address _depositor, uint256 _depositAmount, uint256 _contractStart, uint256 _contractEnd) public whenNotPaused {
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

    function payDeposit(uint256 _contractId) public nonReentrant whenNotPaused {
        DepositContract storage depositContract = contracts[_contractId];
        
        if (depositContract.id == 0) revert ContractDoesNotExist();
        if (depositContract.status != ContractStatus.WAITING_FOR_DEPOSIT) revert InvalidStatus();
        if (depositContract.depositor != msg.sender) revert OnlyDepositorCanPay();
        
        uint256 fee = (depositContract.depositAmount * platformFee) / 10000;

        depositContract.status = ContractStatus.ACTIVE;
        activeContractsForAutoRelease.push(_contractId);

        USDC_TOKEN.safeTransferFrom(msg.sender, address(this), depositContract.depositAmount);
        if (fee > 0) {
            USDC_TOKEN.safeTransferFrom(msg.sender, feeRecipient, fee);
        }
        
        emit DepositPaid(_contractId, msg.sender);
    }

    function getContract(uint256 _contractId) public view returns (DepositContract memory) {
        if (contracts[_contractId].id == 0) revert ContractDoesNotExist();
        return contracts[_contractId];
    }

    function raiseDispute(
        uint256 _contractId, 
        uint256 _claimedAmount, 
        string memory _evidenceHash
    ) public whenNotPaused {
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

    function respondToDispute(uint256 _contractId, string memory _responseHash) public whenNotPaused {
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

        if (depositContract.id == 0) revert ContractDoesNotExist();
        if (msg.sender != depositContract.depositor) revert OnlyDepositorCanResolveTimeout();
        if (depositContract.status != ContractStatus.DISPUTED) revert InvalidStatus();
        
        uint256 requiredTime = _getDisputeRequiredTime(_contractId);
        if (block.timestamp < requiredTime) {
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
        
        depositContract.status = ContractStatus.COMPLETED;
        USDC_TOKEN.safeTransfer(depositContract.depositor, depositContract.depositAmount);
    }

    function _resolveDisputeToDepositor(uint256 _contractId) internal {
        DepositContract storage depositContract = contracts[_contractId];
        
        if (depositContract.id == 0) revert ContractDoesNotExist();
        if (depositContract.status != ContractStatus.DISPUTED) revert InvalidStatus();
                
        depositContract.status = ContractStatus.RESOLVED;
        USDC_TOKEN.safeTransfer(depositContract.depositor, depositContract.depositAmount);
    }

    function setForwarder(address _forwarder) external onlyOwner {
        address oldForwarder = forwarder;
        forwarder = _forwarder;
        emit ForwarderUpdated(oldForwarder, _forwarder);
    }

    function setResolver(address _newResolver) external onlyOwner {
        if (_newResolver == address(0)) revert InvalidResolverAddress();
        if (_newResolver == address(this)) revert InvalidResolverAddress();
        if (_newResolver == resolver) revert ResolverUnchanged();

        address oldResolver = resolver;
        resolver = _newResolver;
        emit ResolverUpdated(oldResolver, _newResolver);
    }

    function setFeeRecipient(address _newFeeRecipient) external onlyOwner {
        if (_newFeeRecipient == address(0)) revert InvalidFeeRecipientAddress();
        if (_newFeeRecipient == address(this)) revert InvalidFeeRecipientAddress();
        if (_newFeeRecipient == feeRecipient) revert FeeRecipientUnchanged();
        
        address oldFeeRecipient = feeRecipient;
        feeRecipient = _newFeeRecipient;
        emit FeeRecipientUpdated(oldFeeRecipient, _newFeeRecipient);
    }

    function rescueTokens(address _token, uint256 _amount) external onlyOwner {
        if (_token == address(0)) revert InvalidUSDCAddress();
        IERC20(_token).safeTransfer(owner(), _amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function checkUpkeep(bytes calldata)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256 autoReleaseChecks = activeContractsForAutoRelease.length > MAX_CHECKS_PER_UPKEEP
            ? MAX_CHECKS_PER_UPKEEP
            : activeContractsForAutoRelease.length;
        
        for (uint256 i = 0; i < autoReleaseChecks; i++) { 
            uint256 contractId = activeContractsForAutoRelease[i];
            DepositContract memory c = contracts[contractId];
            
            if (block.timestamp >= c.autoReleaseTime) {
                return (true, abi.encode(contractId, ActionType.AUTO_RELEASE));
            }
        }
        
        uint256 disputeChecks = disputedContractsForTimeout.length > MAX_CHECKS_PER_UPKEEP
            ? MAX_CHECKS_PER_UPKEEP
            : disputedContractsForTimeout.length;
        
        for (uint256 i = 0; i < disputeChecks; i++) {
            uint256 contractId = disputedContractsForTimeout[i];
            uint256 requiredTime = _getDisputeRequiredTime(contractId);
            
            if (block.timestamp >= requiredTime) {
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

            uint256 requiredTime = _getDisputeRequiredTime(contractId);
            
            if (block.timestamp < requiredTime) {
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

    function _getDisputeRequiredTime(uint256 _contractId) internal view returns (uint256) {
        Dispute memory dispute = disputes[_contractId];
        
        if (dispute.depositorResponded) {
            return dispute.disputeStartTime + DISPUTE_RESOLUTION_TIME + DISPUTE_EXTENSION_TIME;
        } else {
            return dispute.disputeStartTime + DISPUTE_RESOLUTION_TIME;
        }
    }
}
