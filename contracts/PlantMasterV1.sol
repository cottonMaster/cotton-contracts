// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./utils/Address.sol";
import "./utils/Ownable.sol";
import "./BEP20/BEP20.sol";

import "./stakings/NativeStaking.sol";

contract PlantMasterV1 is Ownable {
    using Address for address;
    
    address[] public slaves;
    
    BEP20 public ngr;
    BEP20 public ctf;
    
    NativeStaking public ngrStaking;
    NativeStaking public ctfStaking;
    NativeStaking public ngrCtfStaking;
    
    uint256 private _default_magnitude = 2 ** 64;
    
    constructor() {
        address sender = _msgSender();
        ctf = new BEP20("Cotton.flowers", "CTF");
        ngr = new BEP20("Non-Growable Resource", "NGR");

        /*
            address tokenContract, 
            address _rewardToken,
            uint256 _tokenPerBlock in Ether, e.g. providing value 1 is resulting 1 * 10**18 in staking contract
            uint256 _tokenMultiplier,
            uint256 _allocation,
            uint256 _startsFrom,
            uint256 _magnitude
        */

        ngrStaking = new NativeStaking(
            address(ngr),
            address(ngr),
            1, 
            2,
            0,
            block.number,
            _default_magnitude
            );
        
        ngrCtfStaking = new NativeStaking(
            address(ngr),
            address(ctf),
            1, 
            2,
            0,
            block.number,
            _default_magnitude
            );
            
        ctfStaking = new NativeStaking(
            address(ctf), 
            address(ctf),
            1, 
            2,
            0,
            block.number,
            _default_magnitude
            );
        
        ngr.addMinter(address(ngrStaking));
        ctf.addMinter(address(ctfStaking));
        ctf.addMinter(address(ngrCtfStaking));
        
        ngr.mint(sender, 500_000*10**ngr.decimals());
        ctf.mint(sender, 500_000*10**ctf.decimals());
        
        slaves.push(address(ngr));
        slaves.push(address(ctf));
        slaves.push(address(ctfStaking));
        slaves.push(address(ngrStaking));
        slaves.push(address(ngrCtfStaking));
    }
    
    function updateNativePool(
        address staking, 
        uint256 _tokenPerBlock, 
        uint256 _tokenMultiplier, 
        uint256 _startsFrom,
        uint256 _magnitude,
        uint256 _allocation
        ) public onlyOwner {
            NativeStaking _staking = NativeStaking(staking);
            _staking.updatePool(
                _tokenPerBlock, 
                _tokenMultiplier, 
                _startsFrom,
                _magnitude,
                _allocation
            );
    }

    function claimFee(address token) public onlyOwner {
        BEP20 _token = BEP20(token);
        uint256 _balance = _token.balanceOf( address(this) );
        if(_balance > 0){
            _token.transfer( _msgSender(), _balance );
        }
    } 
    
    function disconnectMinter(address from, address minter) public onlyOwner returns (bool success) {
        (bool _success, ) = from.call(abi.encodeWithSignature("removeMinter(address)", minter));
        require(_success, 'Operation failed');
        
        return _success;
    }
    
    function migratetoV2(address v2) public onlyOwner returns (bool success) {
        for (uint256 i = 0; i < slaves.length; i++){
            (bool _success, ) = slaves[i].call(abi.encodeWithSignature("transferOwnership(address)", v2));
            require(_success, 'Migration failed');
        }
        
        return true;
    }
    
    function addSlave(address slave) public onlyOwner returns (bool insert) {
        for (uint i = 0; i < slaves.length; i++){
            if( slaves[i] == slave ) {
                return true;
            }
        }
        
        for (uint i = 0; i < slaves.length; i++){
            if( slaves[i] == address(0) ) {
                slaves[i] = slave;
                return true;
            }
        }
        slaves.push(slave);
    }

    function removeSlave(address slave) public onlyOwner returns (bool success) {
        for (uint i = 0; i < slaves.length; i++){
            if(slaves[i] == slave){
                if (i >= slaves.length) return false;

                for (uint j = i; j < slaves.length-1; j++){
                    slaves[j] = slaves[j+1];
                }
                delete slaves[slaves.length-1];
            }
        }
        
        return true;
    }
}
