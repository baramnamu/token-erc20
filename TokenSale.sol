pragma solidity ^0.4.21;

import "./SafeMath.sol";

contract Ownable {
    address internal owner;

    /* you have to use this contract to be inherited because it is internal.*/
    constructor() internal {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
    
}

contract Pausable is Ownable {
    event Pause();
    event Unpause();

    bool internal paused;

    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    modifier whenPaused() {
        require(paused);
        _;
    }

    modifier noReentrancy() {
        require(!paused);
        paused = true;
        _;
        paused = false;
    }

    /* When you discover your smart contract is under attack, you can buy time to upgrade the contract by 
       immediately pausing the contract.
     */   
    function pause() public onlyOwner whenNotPaused {
        paused = true;
        emit Pause();
    }

    function unpause() public onlyOwner whenPaused {
        paused = false;
        emit Unpause();
    }
}

interface token {
    function balanceOf(address _account) external view returns (uint256 balance);
    function transfer(address receiver, uint256 amount) external;
}

/**
 * General ERC20 Token Sale(ICO)
 * Written by Shin HyunJae
 * version 19
 */
contract TokenSale is Pausable {
    using SafeMath for uint256;
    
    address public beneficiary;                         // In_The_Dream(Company)'s address 
    uint256 public amountRaised;
    uint256 public deadline;
    uint256 public price;
    uint256 public bottomLimitForFund = 0.5 * 1 ether;  // The Bottom Limit for each funding
    uint256 public maxCap = 200 * 1 ether;              // Maximum Cap Limit for each funder
    token public tokenReward;
    mapping(address => uint256) public balanceOf;
    mapping(address => uint8) public whiteList;
    bool saleClosed = true;
    
    event FundTransfer(address backer, uint256 amount, bool isContribution);
    
    /**
     * Constructor function
     *
     * Setup the owner
     */
    constructor(
        address ifSuccessfulSendTo,
        uint256 durationInMinutes,
        uint256 newBuyPrice,
        uint256 newMaxCapInEthers,
        address addressOfTokenUsedAsReward
    ) public {
        beneficiary = ifSuccessfulSendTo;
        deadline = now + durationInMinutes * 1 minutes;
        price = newBuyPrice;
        maxCap = newMaxCapInEthers.mul(1 ether);
        tokenReward = token(addressOfTokenUsedAsReward);
    }
    
    /**
     * Open Token Sale
     * 
     * Before open this sale, transfer all tokens except for ICO to beneficiary that is "In The Dream" company's address 
     */
    function openSale(uint256 _valueForIcoTokens) external onlyOwner {
        require(saleClosed);
        uint256 tokenBalance = tokenReward.balanceOf(this);
        require(tokenBalance > 0 && _valueForIcoTokens > 0);
        require(tokenBalance >= _valueForIcoTokens);

        if (tokenBalance.sub(_valueForIcoTokens) > 0) tokenReward.transfer(beneficiary, tokenBalance.sub(_valueForIcoTokens));
        saleClosed = false; // open this sale
    }
    
    /**
     * set the saleClosed variable flag
     * 
     * set the saleClosed variable flag true to open this tokens sale
     */
    function setSaleClosed(bool _value) external onlyOwner {
        saleClosed = _value;
    }
    
    function getSaleClosed() external view returns (bool _saleClosed) {
        _saleClosed = saleClosed;
        return _saleClosed;
    }
    
    /**
     * set the white list
     * 
     * add or remove the white list of the funder
     */
    function setWhiteList(address _funder, uint8 _grade) public onlyOwner {
        whiteList[_funder] = _grade;
    }
    
    /**
     * add the white list
     * 
     * add the white list of the funder
     */
    function addWhiteList(address _funder) external onlyOwner {
        setWhiteList(_funder, 10);
    }
    
    /**
     * remove the white list
     * 
     * remove the white list of the funder
     */
    function removeWhiteList(address _funder) external onlyOwner {
        setWhiteList(_funder, 0);
    }
    
    function getWhiteList(address _funder) external view returns (uint8 grade) {
        grade = whiteList[_funder];
        return grade;
    }
    
    /**
     * Fallback function
     *
     * The function without name is the default function that is called whenever anyone sends funds to a contract
     */
    function () payable external {
        uint256 amount = msg.value;

        require(!saleClosed);
        require(msg.value >= bottomLimitForFund);
        // Check the white List of the funder
        require(whiteList[msg.sender] > 0);
        // Check the maximum cap for each funder
        require(maxCap >= balanceOf[msg.sender].add(amount));
        
        balanceOf[msg.sender] = balanceOf[msg.sender].add(amount);
        amountRaised = amountRaised.add(amount);
        tokenReward.transfer(msg.sender, amount.mul(price));
        emit FundTransfer(msg.sender, amount, true);
    }
    
    modifier afterDeadline() { if (now >= deadline) _; }
    
    /**
     * Get remaining time
     * 
     * Get remaining time in minutes to deadline of token sale
     */
    function getRemainingTime() external view returns (uint256 remainingTime) {
        remainingTime = (deadline > now && deadline - now >= 60) ? (deadline - now) / 1 minutes : 0;
        return remainingTime;
    }
    
    /**
     * Withdraw the remaining tokens
     *
     * Checks if the goal or time limit has been reached and ends the campaign
     */
    function withdrawRemainingTokens(address _recipient) onlyOwner public {
        uint256 tokenBalance = tokenReward.balanceOf(this);
        if (tokenBalance > 0) tokenReward.transfer(_recipient, tokenBalance);
    }

    /**
     * Close Token Sale
     *
     * Checks if the time limit has been reached and ends the campaign
     */
    function closeSale() afterDeadline onlyOwner external {
        require(!saleClosed);
        if (beneficiary.send(amountRaised)) {
            emit FundTransfer(beneficiary, amountRaised, false);
        }
        withdrawRemainingTokens(beneficiary);
        saleClosed = true;
    }

    /**
     * Destroy this contract
     *
     * @notice Remove this contract from the system irreversibly and send remain funds to owner account
     * @notice 정식 배포시 삭제예정
     */
    function destroy() external onlyOwner {
        destroyAndSend(owner);
    }
    
    /**
     * Destroy this contract
     *
     * @notice Remove this contract from the system irreversibly and send remain funds to _recipient account
     * @notice 정식 배포시 삭제예정
     * 
     * @param _recipient Address to receive the funds
     */
    function destroyAndSend(address _recipient) public onlyOwner {
        uint256 tokenBalance = tokenReward.balanceOf(this);
        require(tokenBalance == 0); // Check if this contract have remaining tokens
        selfdestruct(_recipient);
    }

}
