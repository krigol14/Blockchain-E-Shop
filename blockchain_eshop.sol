// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Final_p18029 {

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
    event BuyTokens(address buyer, uint256 ethAmount, uint256 tokenAmount);

    string public constant name = "p18029Coin";
    string public constant symbol = "PCN";
    // initialize the tokens total supply and exchange rate, can be changed later by the admins
    uint256 totalSupply_ = 10000;
    uint256 tokensPerEth = 100;

    mapping(address => uint256) balances;                       // map an address to its balance
    mapping(address => mapping (address => uint256)) allowed;   // store the number of tokens a delegate address can withdraw from another one

    // constructor is called when the smart contract is deployed
    constructor() payable {
        balances[address(this)] = totalSupply_;

        // the admin addresses are defined when the contract is deployed, 
        // however, they can change them later if they wish
        // admin1 is the deployer of the contract
        admin1 = payable(msg.sender);       
        admin2 = payable(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);  
        admin3 = payable(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db);
    }

    // return the total supply of tokens of our contract
    function totalSupply() public view returns (uint256) {
      return totalSupply_;
    }

    // return the token balance of a specific account
    function balanceOf(address tokenOwner) public view returns (uint) {
        return balances[tokenOwner];
    }

    /* 
     * receiver is the address of the account that will receive tokens
     * numTokens is the number of tokens that will be sent to the receiver account
     */
    function transfer(address receiver, uint numTokens) public returns (bool) {
        require(balances[msg.sender] >= numTokens);
        balances[msg.sender] -= numTokens;
        balances[receiver] += numTokens;
        emit Transfer(msg.sender, receiver, numTokens);
        return true;
    }

    // allows delegate to withdraw from the msg.senders account multiple times, up to the numTokens amount
    function approve(address delegate, uint numTokens) public returns (bool) {
        allowed[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender, delegate, numTokens);
        return true;
    }

    // returns the amount of tokens the delegate is allowed to withdraw from owner
    function allowance(address owner, address delegate) public view returns (uint) {
        return allowed[owner][delegate];
    }

    /* 
     * transfer tokens from an account to another one
     * owner is the address of the balances from which we will transfer the numTokens 
     * buyer is the address in the balances that we will credit the numTokens 
     * numTokens is the number of tokens to be transferred from owner to buyer
     */
    function transferFrom(address owner_, address buyer_, uint numTokens) public returns (bool) {
        require(numTokens <= balances[owner_]);
        require(numTokens <= allowed[owner_][msg.sender]);       // allowed[owner][msg.sender] = the number of tokens the msg.sender is allowed to withdraw from the owner

        balances[owner_] -= numTokens;
        balances[buyer_] += numTokens;
        allowed[owner_][msg.sender] -= numTokens;
        emit Transfer(owner_, buyer_, numTokens);
        return true;
    }

    // return the eth balance of an address
    function ethBalance(address ethOwner) public view returns (uint) {
        return ethOwner.balance / 10 ** 18;
    }

    // the exchange rate between our token and eth can be changed using this function
    function defineExchangeRate(uint tokensPerEth_) public onlyAdmin {
        tokensPerEth = tokensPerEth_;
    }

    // return the exchange rate of our token
    function tokenEthExchangeRate() public view returns (uint) {
        return tokensPerEth;
    }

    // minting shop tokens using ether
    function buyTokens() external payable {
        uint256 tokensToBuy = (msg.value / 10 ** 18) * tokensPerEth;
        require((msg.value / 10 ** 18) > 0, "You should send some eth in order to buy tokens");

        balances[msg.sender] += tokensToBuy;

        emit Transfer(address(this), msg.sender, tokensToBuy);
        emit BuyTokens(msg.sender, msg.value, tokensToBuy);
    }

    address payable admin1;
    address payable admin2;
    address payable admin3;
    bool public admin1_acceptsTransaction = false;
    bool public admin2_acceptsTransaction = false;
    bool public admin3_acceptsTransaction = false;

    bool public admin1_acceptsAddressChange = false;
    bool public admin2_acceptsAddressChange = false;
    bool public admin3_acceptsAddressChange = false;

    address payable buyer;
    uint public amount_sent;
    string public orderId;

    // represents the orders state
    enum State {Initial, Pending}
    State public state;

    // purchase acceptance functions for each administrator
    function admin1_acceptTransaction() external {
        require(msg.sender == admin1, "Only admin1 can do that!");
        admin1_acceptsTransaction = true;
    }

    function admin2_acceptTransaction() external {
        require(msg.sender == admin2, "Only admin2 can do that!");
        admin2_acceptsTransaction = true;
    }

    function admin3_acceptTransaction() external {
        require(msg.sender == admin3, "Only admin3 can do that!");
        admin3_acceptsTransaction = true;
    }

    // address change approval function for all admins
    function admin1_acceptAddressChange() external inState(State.Initial) {
        require(msg.sender == admin1, "Only admin1 can do that!");
        admin1_acceptsAddressChange = true;
    }
    
    function admin2_acceptAddressChange() external inState(State.Initial) {
        require(msg.sender == admin2, "Only admin2 can do that!");
        admin2_acceptsAddressChange = true;
    }

    function admin3_acceptAddressChange() external inState(State.Initial) {
        require(msg.sender == admin3, "Only admin3 can do that!");
        admin3_acceptsAddressChange = true;
    }

    // allow the buyer to send money for his purchase, using his order identifier
    function pay(string memory order_id, uint tokensToSend) external inState(State.Initial) {
        state = State.Pending;              // change the state to pending after the buyer pays for his purchase
        buyer = payable(msg.sender);        // buyer is the user who invoked this function 
        require(balances[buyer] >= tokensToSend, "You don't have enough tokens to complete this purchase!");
        
        balances[buyer] -= tokensToSend;
        
        orderId = order_id;
        amount_sent = tokensToSend;
    }

    // the buyer can cancel his purchase if it's still pending 
    function cancelPurchase() external inState(State.Pending) onlyBuyer {
        state = State.Initial;                  // change the state to initial after the buyer cancels his purchase
        balances[buyer] += amount_sent;         // buyer gets his tokens back after cancelling the purchase

        // reset state variables after purchase has been canceled
        reset();
    }

    // the admins can check the details of a purchase so that it can be either accepted or declined
    function checkPurchaseDetails() external view inState(State.Pending) onlyAdmin returns (address, string memory, uint) {
        return (buyer, orderId, amount_sent);
    }

    // each admin can change his address
    function changeAddress(address new_address) external inState(State.Initial) onlyAdmin {
        if (msg.sender == admin1 && (admin2_acceptsAddressChange == true && admin3_acceptsAddressChange == true)) {
            admin1 = payable(new_address);
        }
        else if (msg.sender == admin2 && (admin1_acceptsAddressChange == true && admin3_acceptsAddressChange == true)) {
            admin2 = payable(new_address);
        }
        else if (msg.sender == admin3 && (admin1_acceptsAddressChange == true && admin2_acceptsAddressChange == true)) {
            admin3 = payable(new_address);
        }
    }

    // each admin can accept a purchase 
    function acceptPurchase() external inState(State.Pending) onlyAdmin {
        state = State.Initial;                      // change the state to initial after purchase is accepted
        balances[address(this)] += amount_sent;     // transfer the tokens to the contracts address

        reset();                                    // reset state variables after purchase has been completed
    }

    // the admins can decline a purchase
    function declinePurchase() external inState(State.Pending) onlyAdmin {
        state = State.Initial;                  // change the state to initial after purchase is declined by an admin
        balances[buyer] += amount_sent;         // buyer gets his money back if the purchase is declined by an admin
        
        // reset state variables after purchase has been declined
        reset();
    }

    /*
     * function for the admins to return money to the client, 
     * if the client asks to cancel the purchase after the payment has been completed
     */
    function returnMoneyAfterCompleted(address payable client, uint tokensToReturn) external onlyAdmin {
        require(balances[address(this)] > tokensToReturn, "Not enough tokens to return to the client");

        if (msg.sender == admin1 && (admin2_acceptsTransaction == true || admin3_acceptsTransaction == true)) {
            balances[address(this)] -= tokensToReturn;
            balances[client] += tokensToReturn; 
        } 
        else if (msg.sender == admin2 && (admin1_acceptsTransaction == true || admin3_acceptsTransaction == true)) {
            balances[address(this)] -= tokensToReturn;
            balances[client] += tokensToReturn;
        } 
        else if (msg.sender == admin3 && (admin1_acceptsTransaction == true || admin2_acceptsTransaction == true)) {
            balances[address(this)] -= tokensToReturn;
            balances[client] += tokensToReturn;
        } 

        // reset the variables after the transaction is completed
        admin1_acceptsTransaction = false;
        admin2_acceptsTransaction = false;
        admin3_acceptsTransaction = false;
    }

    // helper function for reseting variables after a purchase has been either completed or rejected
    function reset() public {
        orderId = " ";
        amount_sent = 0;
        admin1_acceptsTransaction = false;
        admin2_acceptsTransaction = false;
        admin3_acceptsTransaction = false;
    }

    // function to check the admin addresses after possible address changes
    function getAdminAddresses() public view onlyAdmin returns (address payable admin_1, address payable admin_2, address payable admin_3) {
        return (admin1, admin2, admin3);
    }

    modifier inState(State state_) {
        require(state == state_, "You can't do that in this current state of the order!");
        _;
    }

    modifier onlyAdmin {
        require(msg.sender == admin1 || msg.sender == admin2 || msg.sender == admin3, "Only an admin can do that!");
        _;
    }

    modifier onlyBuyer {
        require(msg.sender == buyer, "Only the buyer can do that!");
        _;
    }
}
