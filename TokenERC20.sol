pragma solidity ^0.4.21;

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

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) external; }

/**
 * NemoLab ERC20 Token 12 
 * Written by Shin HyunJae
 */
contract TokenERC20 is Pausable {
    // Public variables of the token
    string public name;
    string public symbol;
    uint8 public decimals = 18;    // 18 decimals is the strongly suggested default, avoid changing it
    uint256 public totalSupply;

    uint256 public sellPrice;
    uint256 public buyPrice;
    
    string constant public terms = "인코디움 약관 201805231506";
    
    /* This creates an array with all balances */
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
    mapping (address => bool) public frozenAccount;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);

    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);

    // This notifies clients about the amount resupplied
    event Resupply(address indexed from, uint256 value);
    
    /* This generates a public event on the blockchain that will notify clients */
    event FrozenFunds(address target, bool frozen);

    /**
     * Constructor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    constructor(string tokenName, string tokenSymbol, uint256 initialSupply, uint8 decimalUnits, uint256 newSellPrice, uint256 newBuyPrice) public {
        name = tokenName;                                       // Set the name for display purposes
        symbol = tokenSymbol;                                   // Set the symbol for display purposes
        if (decimalUnits > 0) decimals = decimalUnits;
        totalSupply = convertToDecimalUnits(initialSupply);     // Update total supply with the decimal amount
        balanceOf[msg.sender] = totalSupply;                    // Give the creator all initial tokens
        sellPrice = newSellPrice;
        buyPrice = newBuyPrice;
    }
    
    /**
     * Convert tokens units to token decimal units
     * 
     * @param _value Tokens units without decimal units 
     */
    function convertToDecimalUnits(uint256 _value) internal view returns (uint256 value) {
        value = _value * 10 ** uint256(decimals);
        return value;
    }
    
    /**
     * Get tokens balance
     * 
     * @notice Query tokens balance of the _account
     * 
     * @param _account Account address to query tokens balance
     */
    function getBalance(address _account) public view returns (uint256 balance) {
        balance = balanceOf[_account];
        return balance;
    }
    
    /**
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint _value) internal {
        require(_to != 0x0);                                        // Prevent transfer to 0x0 address. Use burn() instead
        require(balanceOf[_from] >= _value);                        // Check if the sender has enough
        require(balanceOf[_to] + _value >= balanceOf[_to]);         // Check for overflows
        require(!frozenAccount[_from]);                             // Check if sender is frozen
        require(!frozenAccount[_to]);                               // Check if recipient is frozen
        uint previousBalances = balanceOf[_from] + balanceOf[_to];  // Save this for an assertion in the future
        
        balanceOf[_from] -= _value;                                 // Subtract from the sender
        balanceOf[_to] += _value;                                   // Add the same to the recipient
        emit Transfer(_from, _to, _value);
        
        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }
    
    /**
     * Transfer tokens
     *
     * @notice Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value) public noReentrancy {
        // _transfer(msg.sender, _to, convertToDecimalUnits(_value));
        _transfer(msg.sender, _to, _value);
    }

    /**
     * Transfer tokens from other address
     *
     * Send `_value` tokens to `_to` on behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom(address _from, address _to, uint256 _value) public noReentrancy returns (bool success) {
        // uint256 tvalue = convertToDecimalUnits(_value);
        require(_value <= allowance[_from][msg.sender]);     // Check allowance
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    /**
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_value` tokens on your behalf
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function approve(address _spender, uint256 _value) public noReentrancy returns (bool success) {
        // allowance[msg.sender][_spender] = convertToDecimalUnits(_value);
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    /**
     * Set allowance for other address and notify
     *
     * @notice Allows `_spender` to spend no more than `_value` tokens on your behalf, and then ping the contract about it
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     * @param _extraData some extra information to send to the approved contract
     */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData) public noReentrancy returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, address(this), _extraData);
            return true;
        }
    }

    /**
     * Destroy tokens
     *
     * Remove `_value` tokens from the system irreversibly
     *
     * @param _value the amount of money to burn
     */
    function burn(uint256 _value) onlyOwner public returns (bool success) {
        // uint256 bvalue = convertToDecimalUnits(_value);
        require(balanceOf[msg.sender] >= _value);   // Check if the sender has enough
        balanceOf[msg.sender] -= _value;            // Subtract from the sender
        totalSupply -= _value;                      // Updates totalSupply
        emit Burn(msg.sender, _value);
        return true;
    }

    /**
     * Destroy tokens from other account
     *
     * @notice Remove `_value` tokens from the system irreversibly on behalf of `_from`.
     *
     * @param _from the address of the sender
     * @param _value the amount of money to burn
     */
    function burnFrom(address _from, uint256 _value) onlyOwner public returns (bool success) {
        // uint256 bvalue = convertToDecimalUnits(_value);
        require(balanceOf[_from] >= _value);                // Check if the targeted balance is enough
        require(_value <= allowance[_from][msg.sender]);    // Check allowance
        balanceOf[_from] -= _value;                         // Subtract from the targeted balance
        allowance[_from][msg.sender] -= _value;             // Subtract from the sender's allowance
        totalSupply -= _value;                              // Update totalSupply
        emit Burn(_from, _value);
        return true;
    }
    
    /** 
     * Mint tokens 
     * 
     * @notice Create `mintedAmount` tokens and send it to `target`
     *
     * @param target Address to receive the tokens
     * @param mintedAmount the amount of tokens it will receive
     */
    function mintToken(address target, uint256 mintedAmount) onlyOwner public {
        // uint256 mAmount = convertToDecimalUnits(mintedAmount);
        require(totalSupply + mintedAmount >= totalSupply);                 // Check for overflows
        // require(balanceOf[target] + mintedAmount >= balanceOf[target]);     // Check for overflows
        balanceOf[target] += mintedAmount;
        totalSupply += mintedAmount;
        emit Transfer(0, address(this), mintedAmount);
        emit Transfer(address(this), target, mintedAmount);
    }

    /**
     * Set sellPrice and buyPrice
     * 
     * @notice Allow users to buy tokens for `newBuyPrice` eth and sell tokens for `newSellPrice` eth
     * 
     * @param newSellPrice Price the users can sell to the contract
     * @param newBuyPrice Price users can buy from the contract
     */
    function setPrices(uint256 newSellPrice, uint256 newBuyPrice) onlyOwner public {
        sellPrice = newSellPrice;
        buyPrice = newBuyPrice;
    }
    
    /**
     * @notice Buy tokens from contract by sending ether
     */
    function buy() payable public noReentrancy returns (uint256 amount) {
        amount = msg.value * buyPrice;                                          // calculates the amount
        // _transfer(address(this), msg.sender, convertToDecimalUnits(amount));    // makes the transfers
        _transfer(address(this), msg.sender, amount);    // makes the transfers
        return amount;
    }
    
    /**
     * @notice Fallback function to buy tokens
     * @notice Let's use this function in ICO smart contract
     */
    // function() payable external {
    //     buy();
    // }
    
    /**
     * @notice Sell `amount` tokens to contract
     * 
     * @param amount amount of tokens to be sold
     */
    function sell(uint256 amount) public noReentrancy returns (uint256 revenue) {
        revenue = amount / sellPrice;
        require(address(this).balance >= revenue);                              // checks if the contract has enough ether to buy
        // _transfer(msg.sender, address(this), convertToDecimalUnits(amount));    // makes the transfers
        _transfer(msg.sender, address(this), amount);    // makes the transfers
        // sends ether to the seller. It's important to do this last to avoid recursion attacks
        msg.sender.transfer(revenue);
        return revenue;
    }
    
    /**
     * Destroy this contract
     *
     * @notice Remove this contract from the system irreversibly and send remain funds to owner account
     */
    function destroy() external onlyOwner {
        selfdestruct(owner);
    }
    
    /**
     * Destroy this contract
     *
     * @notice Remove this contract from the system irreversibly and send remain funds to _recipient account
     * 
     * @param _recipient Address to receive the funds
     */
    function destroyAndSend(address _recipient) external onlyOwner {
        selfdestruct(_recipient);
    }

}