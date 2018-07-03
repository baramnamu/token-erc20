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
 * Secured Deposit(보호예수) Smart Contract
 * Written by Shin HyunJae
 * version 2
 */
contract SafeDeposit is Pausable {
    using SafeMath for uint256;
    
    uint256 public endOfPeriod;
    mapping(address => uint256) public holdingBalanceOf;
    token public tokenReward;
    
    event Withdraw(address recipient, uint256 amount);
    
    /**
     * Constructor function
     *
     * Setup the owner
     */
    constructor(
        address addressOfTokenUsedAsReward
    ) public {
        tokenReward = token(addressOfTokenUsedAsReward);
        // endOfPeriod = (24 * 60 * 365 * 1 minutes) + now;    // 1 year
        endOfPeriod = (60 * 1 minutes) + now;    // 1 hour
        
        // Secured address list
        uint256 decimals = 18;
        holdingBalanceOf[0xf17f52151ebef6c7334fad080c5704d77216b732] = uint256(5000).mul(10 ** decimals);
        holdingBalanceOf[0xc5fdf4076b8f3a5357c5e395ab970b5b54098fef] = uint256(10000).mul(10 ** decimals);
        holdingBalanceOf[0x821aea9a577a9b44299b9c15c88cf3087f3b5544] = uint256(15000).mul(10 ** decimals);
    }

    modifier afterDeadline() { require(now >= endOfPeriod); _; }

    /**
     * Fallback function
     *
     * The function without name is the default function that is called whenever anyone sends funds to a contract
     */
    function () payable external afterDeadline {
        require(holdingBalanceOf[msg.sender] > 0);
        uint256 amount = holdingBalanceOf[msg.sender];
        tokenReward.transfer(msg.sender, amount);
        holdingBalanceOf[msg.sender] = 0;
        emit Withdraw(msg.sender, amount);
    }

    /**
     * Withdraw the remaining tokens
     *
     * @notice Withdraw the remaining tokens from this contract to _recipient.
     */
    function withdrawRemainingTokens(address _recipient) onlyOwner public {
        uint256 tokenBalance = tokenReward.balanceOf(this);
        if (tokenBalance > 0) tokenReward.transfer(_recipient, tokenBalance);
    }

    /**
     * Withdraw the remaining ether
     *
     * @notice Withdraw the remaining ether from this contract to _recipient.
     */
    function withdrawRemainingEther(address _recipient) onlyOwner public {
        uint256 remainingBalance = address(this).balance;
        require(remainingBalance > 0);
        _recipient.transfer(remainingBalance);
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
