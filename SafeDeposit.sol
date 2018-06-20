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
    function decimals() external view returns (uint8);
    function balanceOf(address _account) external view returns (uint256 balance);
    function transfer(address receiver, uint amount) external;
}

/**
 * Secured Deposit(보호예수) Smart Contract
 * Written by Shin HyunJae
 * version 2
 */
contract SafeDeposit is Pausable {
    using SafeMath for uint256;
    
    uint public endOfPeriod;
    mapping(address => uint256) public holdingBalanceOf;
    token public tokenReward;
    uint8 public decimals = 18;
    
    event Withdraw(address recipient, uint amount);
    
    /**
     * Constructor function
     *
     * Setup the owner
     */
    constructor(
        address addressOfTokenUsedAsReward
    ) public {
        tokenReward = token(addressOfTokenUsedAsReward);
        endOfPeriod = (24 * 60 * 365 * 1 minutes) + now;    // 1 year
        decimals = tokenReward.decimals();
        
        // Secured address list
        holdingBalanceOf[0xf8D086f16BaC2c49Ffb291FaDf9FBa4B618C25E2] = uint(5000).mul(10 ** uint(decimals));
        holdingBalanceOf[0xCE5046248FdcC325164bd98A26715d9E9B573825] = uint(2000).mul(10 ** uint(decimals));
        holdingBalanceOf[0x970397fF7AdDEFA7c639777e3dF105f7ee3F11D7] = uint(2000).mul(10 ** uint(decimals));
    }

    modifier afterDeadline() { require(now >= endOfPeriod); _; }

    /**
     * Fallback function
     *
     * The function without name is the default function that is called whenever anyone sends funds to a contract
     */
    function () payable external afterDeadline {
        require(holdingBalanceOf[msg.sender] > 0);
        uint amount = holdingBalanceOf[msg.sender];
        tokenReward.transfer(msg.sender, amount);
        holdingBalanceOf[msg.sender] = 0;
        emit Withdraw(msg.sender, amount);
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
