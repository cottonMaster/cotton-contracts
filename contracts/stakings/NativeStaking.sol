// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../utils/SafeMath.sol';
import '../utils/Context.sol';
import '../BEP20/BEP20.sol';

contract NativeStaking is Context, Ownable {
    using SafeMath for uint256;
    BEP20 public token;
    BEP20 public rewardToken;
    uint256 public tokenPerBlock;
    uint256 public tokenMultiplier;
    uint256 public startsFrom;     // block number
    uint256 public allocation;     // how many tokens will be minted during pool, 0 == unlimited
    uint256 public _decimals;
    uint256 private magnitude;
    address private fee;
    bool public poolStatus;

    constructor (
        address tokenContract, 
        address _rewardToken,
        uint256 _tokenPerBlock, 
        uint256 _tokenMultiplier,
        uint256 _allocation,
        uint256 _startsFrom,
        uint256 _magnitude
        ) {
        token = BEP20(tokenContract);
        rewardToken = BEP20(_rewardToken);
        _decimals = token.decimals();
        tokenPerBlock = _tokenPerBlock * 10**_decimals;
        tokenMultiplier = _tokenMultiplier;
        startsFrom = _startsFrom;
        allocation = (uint256)(_allocation*(uint256)(_decimals));
        magnitude = _magnitude;
        fee = owner();
        poolStatus = true;
    }
    
    modifier isActivePool() {
        require(poolStatus == true, "NativeStaking:: staking pool disabled");
        _;
    }
    
    address[] public stakers;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public stakes;
    mapping(address => uint256) public payoutsTo;

    uint256 public totalDeposits;
    uint256 public totalRewards;
    

    function deposit(uint256 amount) external isActivePool {
        require(_msgSender() == tx.origin); // preventing flash-loans
        _stakeToken(_msgSender(), amount);
    } 
    
    function _stakeToken(address sender, uint256 amount) internal {
        uint256 _amount = amount / magnitude;
        uint256 _fee = amount.sub(_amount * magnitude);
        token.transferFrom(sender, address(this), _amount*magnitude);
        token.transferFrom(sender, address(fee), _fee);
        uint256 rewardDebt = calculateYield(sender) / magnitude;
        _amount = _amount.add(rewardDebt);
        require(_amount > 0, "Amount too low to stake");
        balances[sender] = balances[sender].add(_amount);
        payoutsTo[sender] = payoutsTo[sender].add(_amount);
        /*
        if(stakers.length > 0){
            stakers[stakers.length+1] = sender;
        } else {
            stakers[0] = sender;
        }
        */
        stakes[sender] = block.number;
        totalDeposits = totalDeposits.add(_amount * magnitude);
        totalRewards = totalRewards.add(rewardDebt * magnitude);
    }
    
    function calculateStakeShare(address sender) public view returns(uint256) {
        if(balances[sender] > 0){
            return (uint256) ( (uint256) (balances[sender]*magnitude*10**_decimals) / totalDeposits );
        }else{
            return 0;
        }
    }

    function calculateYield(address sender) internal view returns(uint256) {
        require(_msgSender() == sender);
        if(balances[sender] > 0) {
            uint256 reward = (uint256) ( (block.number.sub(stakes[sender]) * (tokenPerBlock*tokenMultiplier)));
            uint256 _amount = (uint256) ( (reward * calculateStakeShare(sender)) / 10**_decimals );
            return _amount;
        } else {
            return 0;
        }
    }
   
    function claimYield(address sender) public returns (bool success) {
        require(_msgSender() == sender);
        uint256 _calculatedDebt = calculateYield(sender);
        uint256 rewardDebt = (uint256) ( _calculatedDebt / magnitude );
        if(rewardDebt > 0) {
            rewardToken.mint( sender, (uint256) (rewardDebt * magnitude) );
            rewardToken.mint( address(fee), _calculatedDebt.sub( (uint256)(rewardDebt * magnitude) ) );
            stakes[sender] = block.number;
            totalRewards = totalRewards.add(rewardDebt * magnitude);
            return true;
        }else{
            return false;
        }
    }
    
    function compoundYield(address sender) public{
        require(_msgSender() == sender);
        uint256 _calculatedDebt = calculateYield(sender);
        uint256 rewardDebt = (uint256) (_calculatedDebt / magnitude);
        require(rewardDebt > 0, "Reward too low");
        balances[sender] = balances[sender].add(rewardDebt);
        payoutsTo[sender] = payoutsTo[sender].add(rewardDebt);
        rewardToken.mint(address(this), _calculatedDebt);
        stakes[sender] = block.number;
        totalDeposits = totalDeposits.add(rewardDebt*magnitude);
        totalRewards = totalRewards.add(rewardDebt*magnitude);
    }
    
    function withdraw(uint256 amount) external {
        address _to = _msgSender();
        claimYield(_to);
        balances[_to] = balances[_to].sub(amount);
        totalDeposits = totalDeposits.sub(amount*magnitude);
        token.transfer(_to, amount*magnitude);  
    }
    
    function updatePool(
        uint256 _tokenPerBlock, 
        uint256 _tokenMultiplier, 
        uint256 _startsFrom,
        uint256 _magnitude,
        uint256 _allocation
        ) external onlyOwner {
            for(uint256 i=0; i < stakers.length; i++){
                compoundYield(stakers[i]);
                balances[stakers[i]] = (balances[stakers[i]]*magnitude)/_magnitude;
            }
            tokenPerBlock = _tokenPerBlock;
            tokenMultiplier = _tokenMultiplier;
            magnitude = _magnitude;
            allocation = _allocation;
            startsFrom = _startsFrom;
    }
    
    function disablePool() external onlyOwner {
    	poolStatus = false;
    }
    
    function enablePool() external onlyOwner {
    	poolStatus = true;
    }
}
