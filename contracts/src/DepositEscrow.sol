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
    error DepositDoesNotExist();
    error PeriodNotEnded();
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

    enum DepositStatus {
        WAITING_FOR_DEPOSIT,
        ACTIVE,
        COMPLETED,
        DISPUTED,
        RESOLVED
    }

    struct Deposit {
        address depositor;       
        DepositStatus status; 
        address beneficiary;    
        uint256 id;             
        uint256 depositAmount;  
        uint256 periodStart; 
        uint256 periodEnd;
        uint256 autoReleaseTime;
    }

    struct Dispute {
        uint256 claimedAmount;
        string evidenceHash;
        string responseHash;
        bool depositorResponded; 
        uint256 disputeStartTime;
    }

    mapping(uint256 => Deposit) public deposits;
    mapping(uint256 => Dispute) public disputes;
    uint256 public nextDepositId;
    address public resolver;
    uint256 public platformFee;
    address public feeRecipient;
    uint256 public constant MAX_PLATFORM_FEE = 1000;
    IERC20 public immutable USDC_TOKEN;

    uint256[] private activeDepositsForAutoRelease;
    uint256[] private disputedDepositsForTimeout;

    uint256 public constant GRACE_PERIOD = 7 days;
    uint256 public constant DISPUTE_RESOLUTION_TIME = 14 days;
    uint public constant DISPUTE_EXTENSION_TIME = 4 days;
    uint256 private constant MAX_CHECKS_PER_UPKEEP = 75;

    address public forwarder;

    event DepositCreated(
        uint256 indexed depositId,
        address indexed depositor,
        address indexed beneficiary,
        uint256 depositAmount,
        uint256 periodStart, 
        uint256 periodEnd,
        uint256 autoReleaseTime 
    );

    event DepositPaid(
        uint256 indexed depositId,
        address indexed depositor,
        uint256 amount 
    );

    event CleanExitConfirmed(
        uint256 indexed depositId,
        address indexed beneficiary
    );

    event DisputeRaised(
        uint256 indexed depositId,
        address indexed beneficiary,
        uint256 claimedAmount,
        string evidenceHash,
        uint256 disputeStartTime,
        uint256 disputeDeadline 
    );

    event DepositorRespondedToDispute(
        uint256 indexed depositId,
        address indexed depositor,
        string responseHash,
        uint256 extendedDeadline
    );

    event ResolverDecisionMade(
        uint256 indexed depositId,
        address indexed resolver,
        uint256 amountToDepositor,
        uint256 amountToBeneficiary
    );

    event DisputeResolvedByTimeout(
        uint256 indexed depositId,
        address indexed depositor,
        uint256 amount
    );

    event AutoReleaseExecuted(
        uint256 indexed depositId,
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
        address indexed newFeeRecipient
    );

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
        nextDepositId = 1;
        USDC_TOKEN = IERC20(_usdcToken);
        forwarder = address(0);
        feeRecipient = _feeRecipient;
    }

    function createDeposit(address _depositor, uint256 _depositAmount, uint256 _periodStart, uint256 _periodEnd) public whenNotPaused {
        if (_depositAmount == 0) revert DepositMustBeGreaterThanZero();
        if (_periodEnd <= _periodStart) revert EndMustBeAfterStart();
        if (_depositor == address(0)) revert InvalidDepositorAddress();

        uint256 depositId = nextDepositId;
        uint256 autoReleaseTime = _periodEnd + GRACE_PERIOD;
    
        deposits[depositId] = Deposit({
            depositor: _depositor,
            status: DepositStatus.WAITING_FOR_DEPOSIT,
            beneficiary: msg.sender, 
            id: depositId,
            depositAmount: _depositAmount,
            periodStart: _periodStart,
            periodEnd: _periodEnd,
            autoReleaseTime: autoReleaseTime
        });

        emit DepositCreated(
            depositId,
            _depositor,
            msg.sender,
            _depositAmount,
             _periodStart, 
            _periodEnd,
            autoReleaseTime
        );
    
        unchecked {
            nextDepositId = depositId + 1;
        }
    }

    function payDeposit(uint256 _depositId) public nonReentrant whenNotPaused {
        Deposit storage deposit = deposits[_depositId];
        
        if (deposit.id == 0) revert DepositDoesNotExist();
        if (deposit.status != DepositStatus.WAITING_FOR_DEPOSIT) revert InvalidStatus();
        if (deposit.depositor != msg.sender) revert OnlyDepositorCanPay();
        
        uint256 fee = (deposit.depositAmount * platformFee) / 10000;

        deposit.status = DepositStatus.ACTIVE;
        activeDepositsForAutoRelease.push(_depositId);

        USDC_TOKEN.safeTransferFrom(msg.sender, address(this), deposit.depositAmount);
        if (fee > 0) {
            USDC_TOKEN.safeTransferFrom(msg.sender, feeRecipient, fee);
        }
        
        emit DepositPaid(_depositId, msg.sender, deposit.depositAmount);
    }

    function getDeposit(uint256 _depositId) public view returns (Deposit memory) {
        if (deposits[_depositId].id == 0) revert DepositDoesNotExist();
        return deposits[_depositId];
    }

    function raiseDispute(
        uint256 _depositId, 
        uint256 _claimedAmount, 
        string memory _evidenceHash
    ) public whenNotPaused {
        Deposit storage deposit = deposits[_depositId];

        if (deposit.id == 0) revert DepositDoesNotExist();
        if (_claimedAmount == 0) revert DepositMustBeGreaterThanZero(); 
        if (deposit.beneficiary != msg.sender) revert OnlyBeneficiaryCanRaiseDispute();
        if (deposit.status != DepositStatus.ACTIVE) revert InvalidStatus();              
        if (block.timestamp < deposit.periodEnd) revert PeriodNotEnded();       
        if (_claimedAmount > deposit.depositAmount) revert AmountExceedsDeposit();
        
        uint256 disputeStartTime = block.timestamp;
        uint256 deadline = disputeStartTime + DISPUTE_RESOLUTION_TIME;
        
        disputes[_depositId] = Dispute({
            claimedAmount: _claimedAmount,
            evidenceHash: _evidenceHash,
            responseHash: "",    
            depositorResponded: false,
            disputeStartTime: disputeStartTime
        });
        
        deposit.status = DepositStatus.DISPUTED; 
        _removeFromArray(activeDepositsForAutoRelease, _depositId);
        disputedDepositsForTimeout.push(_depositId);

        emit DisputeRaised(_depositId, msg.sender, _claimedAmount, _evidenceHash, disputeStartTime, deadline);
    }

    function respondToDispute(uint256 _depositId, string memory _responseHash) public whenNotPaused {
        Deposit storage deposit = deposits[_depositId];

        if (deposit.id == 0) revert DepositDoesNotExist();
        if (msg.sender != deposit.depositor) revert OnlyDepositorCanRespond();
        if (deposit.status != DepositStatus.DISPUTED) revert InvalidStatus();
        if (disputes[_depositId].depositorResponded) revert AlreadyResponded();
        
        Dispute storage dispute = disputes[_depositId];
        dispute.responseHash = _responseHash;
        dispute.depositorResponded = true;

        uint256 newDeadline = dispute.disputeStartTime 
            + DISPUTE_RESOLUTION_TIME 
            + DISPUTE_EXTENSION_TIME;
        
        emit DepositorRespondedToDispute(_depositId, msg.sender, _responseHash, newDeadline);
    }

    function makeResolverDecision(uint256 _depositId, uint256 _amountToBeneficiary) public nonReentrant {
        Deposit storage deposit = deposits[_depositId];

        if (resolver != msg.sender) revert OnlyResolverCanDecide();
        if (deposit.id == 0) revert DepositDoesNotExist();
        if (deposit.status != DepositStatus.DISPUTED) revert InvalidStatus(); 
        if (_amountToBeneficiary > deposit.depositAmount) revert AmountExceedsDeposit();
        
        USDC_TOKEN.safeTransfer(deposit.beneficiary, _amountToBeneficiary);

        uint256 amountToDepositor = deposit.depositAmount - _amountToBeneficiary;

        USDC_TOKEN.safeTransfer(deposit.depositor, amountToDepositor);
        
        deposit.status = DepositStatus.RESOLVED;
        _removeFromArray(disputedDepositsForTimeout, _depositId);
        
        emit ResolverDecisionMade(_depositId, msg.sender, amountToDepositor, _amountToBeneficiary);
    }

    function resolveDisputeByTimeout(uint256 _depositId) public nonReentrant {
        Deposit storage deposit = deposits[_depositId];

        if (deposit.id == 0) revert DepositDoesNotExist();
        if (msg.sender != deposit.depositor) revert OnlyDepositorCanResolveTimeout();
        if (deposit.status != DepositStatus.DISPUTED) revert InvalidStatus();
        
        uint256 requiredTime = _getDisputeRequiredTime(_depositId);
        if (block.timestamp < requiredTime) {
            revert DisputeStillActive();
        }
        
        _resolveDisputeToDepositor(_depositId);
        _removeFromArray(disputedDepositsForTimeout, _depositId);
        
        emit DisputeResolvedByTimeout(_depositId, deposit.depositor, deposit.depositAmount);
    }

    function confirmCleanExit(uint256 _depositId) public nonReentrant {
        Deposit storage deposit = deposits[_depositId];

        if (deposit.beneficiary != msg.sender) revert OnlyBeneficiaryCanConfirm();
        if (block.timestamp < deposit.periodEnd) revert PeriodNotEnded();
        
        _releaseDepositToDepositor(_depositId);
        _removeFromArray(activeDepositsForAutoRelease, _depositId);
        
        emit CleanExitConfirmed(_depositId, msg.sender);
    }

    function _releaseDepositToDepositor(uint256 _depositId) internal {
        Deposit storage deposit = deposits[_depositId];
        
        if (deposit.id == 0) revert DepositDoesNotExist();
        if (deposit.status != DepositStatus.ACTIVE) revert InvalidStatus();
        
        deposit.status = DepositStatus.COMPLETED;
        USDC_TOKEN.safeTransfer(deposit.depositor, deposit.depositAmount);
    }

    function _resolveDisputeToDepositor(uint256 _depositId) internal {
        Deposit storage deposit = deposits[_depositId];
        
        if (deposit.id == 0) revert DepositDoesNotExist();
        if (deposit.status != DepositStatus.DISPUTED) revert InvalidStatus();
                
        deposit.status = DepositStatus.RESOLVED;
        USDC_TOKEN.safeTransfer(deposit.depositor, deposit.depositAmount);
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
        uint256 autoReleaseChecks = activeDepositsForAutoRelease.length > MAX_CHECKS_PER_UPKEEP
            ? MAX_CHECKS_PER_UPKEEP
            : activeDepositsForAutoRelease.length;
        
        for (uint256 i = 0; i < autoReleaseChecks; i++) { 
            uint256 depositId = activeDepositsForAutoRelease[i];
            Deposit memory d = deposits[depositId];
            
            if (block.timestamp >= d.autoReleaseTime) {
                return (true, abi.encode(depositId, ActionType.AUTO_RELEASE));
            }
        }
        
        uint256 disputeChecks = disputedDepositsForTimeout.length > MAX_CHECKS_PER_UPKEEP
            ? MAX_CHECKS_PER_UPKEEP
            : disputedDepositsForTimeout.length;
        
        for (uint256 i = 0; i < disputeChecks; i++) {
            uint256 depositId = disputedDepositsForTimeout[i];
            uint256 requiredTime = _getDisputeRequiredTime(depositId);
            
            if (block.timestamp >= requiredTime) {
                return (true, abi.encode(depositId, ActionType.DISPUTE_TIMEOUT));
            }
        }
        
        return (false, "");
    }

    function performUpkeep(bytes calldata performData) external override onlyForwarder nonReentrant {
        (uint256 depositId, ActionType action) = abi.decode(performData, (uint256, ActionType));
        Deposit storage deposit = deposits[depositId];

        if (action == ActionType.AUTO_RELEASE) {
            if (block.timestamp < deposit.autoReleaseTime) {
                revert TooEarlyForAutoRelease();
            }
            
            _releaseDepositToDepositor(depositId);
            _removeFromArray(activeDepositsForAutoRelease, depositId);
            
            emit AutoReleaseExecuted(depositId, deposit.depositor, deposit.depositAmount);
            
        } else if (action == ActionType.DISPUTE_TIMEOUT) {

            uint256 requiredTime = _getDisputeRequiredTime(depositId);
            
            if (block.timestamp < requiredTime) {
                revert DisputeStillActive();
            }

            _resolveDisputeToDepositor(depositId);
            _removeFromArray(disputedDepositsForTimeout, depositId);

            emit DisputeResolvedByTimeout(depositId, deposit.depositor, deposit.depositAmount);
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

    function _getDisputeRequiredTime(uint256 _depositId) internal view returns (uint256) {
        Dispute memory dispute = disputes[_depositId];
        
        if (dispute.depositorResponded) {
            return dispute.disputeStartTime + DISPUTE_RESOLUTION_TIME + DISPUTE_EXTENSION_TIME;
        } else {
            return dispute.disputeStartTime + DISPUTE_RESOLUTION_TIME;
        }
    }
}
