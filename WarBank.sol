//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }
}

contract WarBank {
    using SafeMath for uint256;

    uint256 public _reserve1;       
    uint256 public _reserve2;   
    
    uint256 public finalizeDate;
    uint256 public newUserBlockWindow = 12 hours;
    
    uint public winner = 0;     

    address payable owner;

    event DepositMade(address indexed accountAddress, uint amount);
    event WithdrawMade(address indexed accountAddress, uint amount);

    struct Player { 
        uint side;
        uint256 balance;
        bool exists;
    }

    mapping (address => Player) public players;

    constructor () {
        owner = payable(address(msg.sender));
    }
    
    modifier onlyOwner() {
        require(owner == msg.sender, "Only owner can execute this function");
        _;
    }
 
    receive() external onlyOwner payable{}

    function enter(uint side) external payable returns(bool) {
        require(msg.value > 0, "Must send BNB");
        require(side == 1 || side == 2, "Side gotta be 1 or 2");
        
        if (block.timestamp >= finalizeDate) {
            revert("this game was finalized");
        }
        
        if (block.timestamp >= newUserDateLimit()) {
            if (players[msg.sender].exists == false) {
                revert("Only already participating players can participate");
            }
        }
        
        if (players[msg.sender].exists == false) {
            Player memory user = Player({
                side: side,
                balance: msg.value,
                exists: true
            });

            players[msg.sender] = user;
            increaseReserves(user.side, msg.value);
        } else {
            Player storage user = players[msg.sender];
            user.balance += msg.value;
            increaseReserves(user.side, msg.value);
        }

        emit DepositMade(msg.sender, msg.value);
        
        return true;
    }

    function poolSize() public view returns(uint) {
        return address(this).balance;
    }

    function getContribution() public view returns (uint256 number) {
        return players[msg.sender].balance;
    }   

    function evaluate() public onlyOwner returns (uint number) {
        if (_reserve1 == _reserve2) {
            winner = 0;
        } else if (_reserve1 > _reserve2) {
            winner = 1;
        } else if (_reserve2 > _reserve1) {
            winner = 2;
        }

        return winner;
    }   

    function claimDeposit() public {
        require(players[msg.sender].balance > 0, "Insufficient balance");
        require(block.timestamp >= finalizeDate, "Not finalized yet"); 
        
        Player memory user = players[msg.sender];
        
        uint256 amount = user.balance;
    
        decreaseReserves(user.side, amount);

        payable(msg.sender).transfer(amount);
            
        delete players[msg.sender];
            
        emit WithdrawMade(msg.sender, amount);
    }
     
    function ownerWithdraw(uint amount) public onlyOwner {
        owner.transfer(amount);
    }
    
    function increaseReserves(uint256 side, uint256 amount) private {
        if (side == 1) {
           _reserve1 = _reserve1.add(amount);
        } else {
           _reserve2 = _reserve2.add(amount);
        }
    }
    
    function decreaseReserves(uint256 side, uint256 amount) private {
        if (side == 1) {
           _reserve1 = _reserve1.sub(amount);
        } else {
           _reserve2 = _reserve2.sub(amount);
        }
    }
    
    function setStopGameDate(uint256 timestamp) public onlyOwner {
        finalizeDate = timestamp;
    }

    function newUserDateLimit() public view returns(uint256) {
        return finalizeDate.sub(newUserBlockWindow);
    }
}
