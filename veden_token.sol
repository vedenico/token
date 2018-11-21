pragma solidity ^0.4.22;

import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";
import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/math/SafeMath.sol";


contract VedenToken is ERC20Detailed, Ownable {

	using SafeMath for uint256;
	using SafeMath for uint8;

	uint256 public weiOneUnitCanBuy;
	address public fundsWallet;           

    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowed;
    uint256 public totalSupply;

    uint256[] public privateICOUpperLimits = new uint256[](3);
    
    uint256 public preIcoStart;
    uint256 public preIcoEnd;
    uint256 public preIcoLength;
    uint256[] public preICOUpperLimits = new uint256[](3);

    uint256 public mainIcoStart;
    uint256 public mainIcoLength;
    uint256 public mainIcoEnd;
    
    enum IcoState { PrivateICO, PreICO, MainICO, Finished }
    IcoState public currentState;


    constructor(
        uint256 _initialAmount,
        string _tokenName,
        string _tokenSymbol,
        uint256 _weiOneUnitCanBuy,
        uint256 _preIcoLength,
        uint256 _mainIcoLength,
        uint256[] _privateICOUpperLimits,
        uint256[] _preICOUpperLimits
    ) payable 
    	ERC20Detailed(_tokenName, _tokenSymbol, 0)
    	public 
    {
    	balances[msg.sender] = _initialAmount;               
        totalSupply = _initialAmount;                        
	    weiOneUnitCanBuy = _weiOneUnitCanBuy;               
        fundsWallet = msg.sender;                            

        preIcoLength = _preIcoLength;
        mainIcoLength = _mainIcoLength;
        
        privateICOUpperLimits = _privateICOUpperLimits;
        preICOUpperLimits = _preICOUpperLimits;
        
        currentState = IcoState.PrivateICO;
	}


    function buy() isIcoOpen payable public {
        uint256 tokenAmount = calculateTokenAmount(msg.value);
        require(tokenAmount > 0 && tokenAmount <= balances[fundsWallet]);

        balances[fundsWallet] = balances[fundsWallet].sub(tokenAmount);
        balances[msg.sender] = balances[msg.sender].add(tokenAmount);
        emit Transfer(fundsWallet, msg.sender, tokenAmount);

        fundsWallet.transfer(msg.value);
    }


    function sell(uint amount) isIcoOpen public returns (uint revenue)  {
        require(balances[msg.sender] >= amount);         
        balances[this] += amount;                        
        balances[msg.sender] -= amount;                  
        revenue = amount * weiOneUnitCanBuy;
        emit Transfer(msg.sender, this, amount);
        msg.sender.transfer(revenue);                     
        return revenue;                                   
    }
    

    function balanceOf(address _owner) public view returns (uint256 amount) {
        return balances[_owner];
    }


    function calculateTokenAmount(uint256 weiAmount) internal constant returns(uint256) {
        
        uint256 tokenAmount = weiAmount.div(weiOneUnitCanBuy);
        
        // Private ICO
        if (currentState == IcoState.PrivateICO) {
            // Minimum
            require(weiAmount >= privateICOUpperLimits[0]);

            // 50% Bonus
            if (weiAmount <= privateICOUpperLimits[1]) {
                return tokenAmount.mul(150).div(100);
            }
            
            // 75% Bonus
            if (weiAmount <= privateICOUpperLimits[2]) {
                return tokenAmount.mul(175).div(100);
            }

            // 100% Bonus
            return tokenAmount.mul(200).div(100);
        }
        // Pre-ICO 
        if (currentState == IcoState.PreICO) {
           // 10% Bonus
           if (weiAmount <= preICOUpperLimits[0]) {
               return tokenAmount.mul(110).div(100);
           }

           // 25% Bonus
           if (weiAmount <= preICOUpperLimits[1]) {
               return tokenAmount.mul(125).div(100);
           }

           // 33% Bonus
           if (weiAmount <= preICOUpperLimits[2]) {
               return tokenAmount.mul(133).div(100);
           }

           // 50% Bonus
           return tokenAmount.mul(110).div(100);
        }
        // Main ICO - No Bonus
        return tokenAmount;
    }
    
    
    function transfer(address _to, uint _value) public isIcoFinished {
        emit Transfer(msg.sender, _to, _value);
    }


    function transferFrom(address _from, address _to, uint _value) public isIcoFinished {
        emit Transfer(_from, _to, _value);
    }
    
    
    function startPreICO() public onlyOwner returns (bool)  {
        require(currentState == IcoState.PrivateICO);
        preIcoStart = block.timestamp;
        currentState = IcoState.PreICO;
        return true;
    }


    function totalSupply() external view returns (uint256 _totalSupply) {
        _totalSupply = totalSupply;
    }


    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
    
    
    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }
    

    modifier isIcoOpen() {
        require(currentState != IcoState.Finished);
        uint256 currentDateTime = block.timestamp;
        if(currentState == IcoState.PreICO) {
            if(currentDateTime.sub(preIcoStart) >= preIcoLength) {
                mainIcoStart = currentDateTime;
                currentState = IcoState.MainICO;
                preIcoEnd = currentDateTime;
                revert("Pre ICO is now finished, token bonus tiers have now changed; purchase has been reverted.");
            }
        }
        else if(currentState == IcoState.MainICO) {
            if(currentDateTime.sub(mainIcoStart) >= mainIcoLength) {
                currentState = IcoState.Finished;
                mainIcoEnd = currentDateTime;
                revert("Main ICO is now finished, tokens can only be transfered now; purchase has been reverted.");
            }
        }
        _;
    }


    modifier isIcoFinished() {
        require(currentState == IcoState.Finished);
        _;
    }

}