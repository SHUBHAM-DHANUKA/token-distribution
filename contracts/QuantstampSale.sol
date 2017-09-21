pragma solidity ^0.4.15;

import './lifecycle/Pausable.sol';
import './math/SafeMath.sol';
import './QuantstampToken.sol';

contract QuantstampSale is Pausable {

    using SafeMath for uint256;

    address public beneficiary;
    uint public fundingGoal;
    uint public fundingCap;
    uint public amountRaised;
    uint public deadline;
    uint public rate;
    QuantstampToken public tokenReward;
    mapping(address => uint256) public balanceOf;
    bool public fundingGoalReached = false;
    bool public fundingCapReached = false;
    bool public saleClosed = false;

    event GoalReached(address _beneficiary, uint _amountRaised);
    event FundTransfer(address _backer, uint _amount, bool _isContribution);

    modifier beforeDeadline()   { require (now < deadline); _; }
    modifier afterDeadline()    { require (now >= deadline); _; }
    modifier saleNotClosed()    { require (!saleClosed); _; }

    function QuantstampSale(
        address ifSuccessfulSendTo,
        uint fundingGoalInEthers,
        uint fundingCapInEthers,
        uint durationInMinutes,
        uint rateQspToEther,
        address addressOfTokenUsedAsReward
    ) {
        require(ifSuccessfulSendTo != address(0));
        beneficiary = ifSuccessfulSendTo;
        fundingGoal = fundingGoalInEthers * 1 ether;
        fundingCap = fundingCapInEthers * 1 ether;
        deadline = now + durationInMinutes * 1 minutes;
        rate = rateQspToEther; //* 1 ether;
        tokenReward = QuantstampToken(addressOfTokenUsedAsReward);
    }

    function () payable whenNotPaused beforeDeadline saleNotClosed {
        uint amount = msg.value;
        balanceOf[msg.sender] += amount;
        amountRaised += amount;

        tokenReward.transferFrom(tokenReward.owner(), msg.sender, amount.mul(rate));
        FundTransfer(msg.sender, amount, true);

        if (!fundingGoalReached) {
            if (amountRaised >= fundingGoal) {
                fundingGoalReached = true;
                GoalReached(beneficiary, amountRaised);
            }
        }

        if (amountRaised >= fundingCap) {
            fundingCapReached = true;
            saleClosed = true;
        }
    }

    // can safely be removed from production code after testing
    function testTransferTokens(address _to, uint amount) external onlyOwner {
        tokenReward.transferFrom(tokenReward.owner(), _to, amount);
    }

    // Allows the owner to withdraw all contributions to the
    // beneficiary if and only if the funding goal has been reached.
    function ownerSafeWithdrawal() onlyOwner {
        require(fundingGoalReached);
        var balanceToSend = this.balance;
        if (beneficiary.send(balanceToSend)) {
            FundTransfer(beneficiary, balanceToSend, false);
        } else {
            // If we fail to send the funds to beneficiary, unlock funders balance
            fundingGoalReached = false;
        }
    }

    // Anybody can recover their funds after the deadline
    // if and only if the funding goal has NOT been reached.
    function safeWithdrawal() afterDeadline whenNotPaused {
        if (!fundingGoalReached) {
            uint amount = balanceOf[msg.sender];
            balanceOf[msg.sender] = 0;
            if (amount > 0) {
                if (msg.sender.send(amount)) {
                    FundTransfer(msg.sender, amount, false);
                } else {
                    balanceOf[msg.sender] = amount;
                }
            }
        }
    }


}