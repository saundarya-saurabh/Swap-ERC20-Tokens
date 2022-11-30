// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract TokenSwap is AccessControl,ReentrancyGuard {

    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

 // Token used for Swap Contract.
    IERC20 public immutable vpayContractAddress;
    IERC20 public immutable busdContractAddress;

    uint256 public price = 100; // 1BUSD = 100 VPAY 
    uint256 public fee   = 100000000000000000;  // 0.1 Gaura As Fee
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    address payable feeDepositAddress;

    error OnlyAdmin(address caller);
    error ZeroAddress();
       
    constructor(IERC20 _vpayAddr, IERC20 _busdAddr , address payable _feeDeposit)  {
        
        if (address(_vpayAddr) == address(0)) {
            revert ZeroAddress();
        }
         if (address(_busdAddr) == address(0)) {
            revert ZeroAddress();
        }
        feeDepositAddress = _feeDeposit;
        vpayContractAddress = _vpayAddr;
        busdContractAddress = _busdAddr;
        //address owner = msg.sender;
         _grantRole(ADMIN_ROLE, msg.sender);
    }
      
      modifier onlyAdmin() {
        // check whether the caller has the ADMIN_ROLE.
        if (!hasRole(ADMIN_ROLE, msg.sender)) {
            // The caller doesnot have the role, revert.
            revert OnlyAdmin(msg.sender);
        }

        // Continue with function execution.
        _;
    }
    // Functions for Admin to be used in Functions
      function isAdmin(address account)
        public
        view
        returns (bool isRoleAssigned)
    {
        return hasRole(ADMIN_ROLE, account);
    }

    event BuyVPAYusingBUSD (address indexed buyer,  uint amount);
    event BuyBUSDusingVPAY (address indexed buyer,  uint amount);
    event ADD_VPAY_ToContract (address indexed Contract, uint amount);
    event ADD_BUSD_ToContract (address indexed Contract, uint amount);
    event Withdraw_VPAY_ToContract (address indexed eoa, uint amount);
    event Withdraw_BUSD_ToContract (address indexed eoa, uint amount);

    // Function To Change Price of Swap By Admin Of The Smart Contract 
    function changePrice (uint _newPrice) onlyAdmin public returns (uint) {
        price = _newPrice;
        return price;
    }

    // Function To Change Fee for Swap By Admin Of The Smart Contract 
    function changeFee (uint _newFee) onlyAdmin public returns (uint) {
        fee = _newFee.mul(1e18);
        return fee;
    }

    // Function To Add VPAY Token By Admin To The Smart Contract 
    function depositVpay (uint _amountToDeposit) onlyAdmin public returns (bool) {
        uint amountToDeposit = _amountToDeposit.mul(1e18);
        uint amount_Available = (vpayContractAddress.balanceOf(msg.sender));
        require (amount_Available >= amountToDeposit,"you don't have sufficient balance");
        vpayContractAddress.transfer(address(this), amountToDeposit);
        emit ADD_VPAY_ToContract(address(this),amountToDeposit);
        return true;
    }
    // Function To Add BUSD Token By Admin To The Smart Contract 
     function depositBUSD (uint _amountToDeposit) onlyAdmin public returns (bool) {
         uint amountToDeposit = _amountToDeposit.mul(1e18);
        uint amount_Available = (busdContractAddress.balanceOf(msg.sender));
        require (amount_Available >= amountToDeposit,"you don't have sufficient balance");
        busdContractAddress.transfer(address(this), amountToDeposit);
        emit ADD_BUSD_ToContract(address(this),amountToDeposit );
        return true;
    }

    // Function To Withdraw VPAY Token From The Smart Contract By Admin 
    function withdraw_VPAY (uint _amountToWithdraw) onlyAdmin public returns (bool) {
        uint amountToWithdraw = _amountToWithdraw.mul(1e18);
        uint amount_Available = (vpayContractAddress.balanceOf(address(this)));
        require (amount_Available >= amountToWithdraw, "contract doesn't has sufficient balance");
        vpayContractAddress.transfer(msg.sender, amountToWithdraw);
        emit Withdraw_VPAY_ToContract(msg.sender,amountToWithdraw );
        return true;
    }

    // Function To Withdraw BUSD Token From The Smart Contract By Admin 
     function withdraw_BUSD (uint _amountToWithdraw) onlyAdmin public returns (bool) {
        uint amountToWithdraw = _amountToWithdraw.mul(1e18);
        uint amount_Available = (busdContractAddress.balanceOf(address(this)));
        require (amount_Available >= amountToWithdraw, "contract doesn't has sufficient balance");
        busdContractAddress.transfer(msg.sender, amountToWithdraw);
        emit Withdraw_BUSD_ToContract(msg.sender,amountToWithdraw );
        return true;
    }

    // Function To Buy VPAY using BUSD Token
        function buyVPAYusingBUSD(uint _busd) public payable returns(bool){
        uint busd = _busd.mul(1e18);
        uint amount_Available = (busdContractAddress.balanceOf(msg.sender));
        require (msg.value == fee);
        require (amount_Available >= busd, "you don't have sufficient balance");
        feeDepositAddress.transfer(msg.value);
        busdContractAddress.transferFrom(msg.sender,address(this), busd);
        uint vpayToTransferreed = (_busd.mul(price)).mul(1e18);
        if (vpayContractAddress.balanceOf(address(this)) > vpayToTransferreed) {
            vpayContractAddress.transfer(msg.sender, vpayToTransferreed);
        }
        //vpayContractAddress.transfer(tx.origin , vpayToTransferreed);
        emit BuyVPAYusingBUSD(msg.sender , vpayToTransferreed);
        return true;  
    }

    // Function To Buy BUSD using VPAY Token.
    // Approve this contract from token contract .
    // Contract should have enough balance.
        function buyBUSDusingVPAY(uint _vpay) public payable returns(bool){
        require(_vpay >= 100);
        require (msg.value == fee);
        uint vpay = _vpay.mul(1e18);
        uint amount_Available = (vpayContractAddress.balanceOf(msg.sender));
        require (amount_Available >= vpay, "you don't have sufficient balance");
        feeDepositAddress.transfer(msg.value);
        vpayContractAddress.transferFrom(msg.sender,address(this), vpay);
        uint busdToTransferreed = (_vpay.div(price)).mul(1e18);
        if (busdContractAddress.balanceOf(address(this)) > busdToTransferreed) {
            busdContractAddress.transfer(msg.sender, busdToTransferreed);
        }
        // busdContractAddress.transfer(tx.origin, busdToTransferreed);
        emit BuyBUSDusingVPAY(msg.sender , busdToTransferreed);
        return true;
    }

    // View Function To Retrive Total VPAY available in Smart Contract 
        function vpayValueInSmartContract () public view onlyAdmin  returns(uint){
            uint vpay_amount_Available = (vpayContractAddress.balanceOf(address(this)));
            return vpay_amount_Available;
        }

    // View Function To Retrive Total BUSD available in Smart Contract
        function busdValueInSmartContract () public view onlyAdmin returns(uint){
            uint busd_amount_Available = (busdContractAddress.balanceOf(address(this)));
            return busd_amount_Available;
        }


    fallback() external {
        revert();
    }

    receive() external payable {
        revert();
    }
}
