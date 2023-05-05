// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "./interface/IERC20.sol";
import "./lib/SafeTransfer.sol";

contract Sandwich {
    using SafeTransfer for IERC20;

    address private authorizedUser;
    bool public isPaused;

    // transfer(address,uint256) function signature
    bytes4 private constant ERC20_TRANSFER_ID = 0xa9059cbb;

    // swap(uint256,uint256,address,bytes) function signature
    bytes4 private constant PAIR_SWAP_ID = 0x022c0d9f;

    // Events
    event RecoveredERC20(address token, address user, uint256 amount);
    event RecoveredETH(address user, uint256 amount);
    event SwapExecuted(address token, address pair, uint128 amountIn, uint128 amountOut, uint8 tokenOutNo);
    event UserUpdated(address oldUser, address newUser);
    event Paused();
    event Unpaused();

    // Constructor sets the initial authorized user
    constructor(address _owner) {
        require(_owner != address(0), "Invalid owner address");
        authorizedUser = _owner;
    }

    // Receive ETH
    receive() external payable {}

    // Function to recover ERC20 tokens from the contract
    function recoverERC20(address token) external onlyUser notPaused {
        require(isSafeToken(token), "Unsafe token");
        uint256 amount = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(msg.sender, amount);
        emit RecoveredERC20(token, msg.sender, amount);
    }

    // Function to recover Ether from the contract
    function recoverETH() external onlyUser notPaused {
        uint256 amount = address(this).balance;
        require(amount > 0, "No ETH to recover");
        payable(msg.sender).transfer(amount);
        emit RecoveredETH(msg.sender, amount);
    }

    // Function to update the authorized user
    function updateUser(address newUser) external onlyUser {
        require(newUser != address(0), "Invalid new user");
        emit UserUpdated(authorizedUser, newUser);
        authorizedUser = newUser;
    }

    // Function to pause the contract
    function pause() external onlyUser {
        isPaused = true;
        emit Paused();
    }

    // Function to unpause the contract
    function unpause() external onlyUser {
        isPaused = false;
        emit Unpaused();
    }

    // Modifier to restrict access to the authorized user
    modifier onlyUser() {
        require(msg.sender == authorizedUser, "Unauthorized");
        _;
    }

    // Modifier to check if the contract is paused
    modifier notPaused() {
        require(!isPaused, "Contract is paused");
        _;
    }

    function isSafeToken(address token) internal view returns (bool) {
        // Check if the token address is a contract
        uint256 size;
        assembly { size := extcodesize(token) }
        if (size == 0) {
            return false;
        }

        // Check if the token implements the ERC20 interface
        IERC20 erc20Token = IERC20(token);
        try erc20Token.totalSupply() returns (uint256 totalSupply) {
            // Check if the total supply is non-zero
            if (totalSupply == 0) {
                return false;
            }
        } catch {
            return false;
        }

        // Check if the token's balanceOf function behaves as expected
        try erc20Token.balanceOf(address(this)) returns (uint256 balance) {
            // Additional checks can be performed on the balance, if needed
        } catch {
            return false;
        }

        // Check if the token's transfer function behaves as expected
        // We attempt a zero-value transfer to ourselves and expect it to succeed
        try erc20Token.transfer(address(this), 0) returns (bool success) {
            if (!success) {
                return false;
            }
        } catch {
            return false;
        }

        // Check if the token's allowance and transferFrom functions behave as expected
        // We attempt to set and use a zero-value allowance and expect it to succeed
        try erc20Token.approve(address(this), 0) returns (bool success) {
            if (!success) {
                return false;
            }
        } catch {
            return false;
        }
        try erc20Token.transferFrom(address(this), address(this), 0) returns (bool success) {
            if (!success) {
                return false;
            }
        } catch {
            return false;
        }

        // Additional checks can be added here, if needed

        // If all checks pass, return true
        return true;
    }
    
    // Fallback function for frontslice and backslice
    fallback() external payable onlyUser notPaused {
        assembly {
            // Extract out the variables
            let token := shr(96, calldataload(0x00))
            let pair := shr(96, calldataload(0x14))
            let amountIn := shr(128, calldataload(0x28))
            let amountOut := shr(128, calldataload(0x38))
            let tokenOutNo := shr(248, calldataload(0x48))

            // Input validation
            if iszero(amountIn) {
                revert("Invalid amountIn")
            }
            if iszero(amountOut) {
                revert("Invalid amountOut")
            }
            if gt(tokenOutNo, 1) {
                revert("Invalid tokenOutNo")
            }

            // **** calls token.transfer(pair, amountIn) ****
            mstore(0x7c, ERC20_TRANSFER_ID)
            mstore(0x80, pair)
            mstore(0xa0, amountIn)

            let s1 := call(sub(gas(), 5000), token, 0, 0x7c, 0x44, 0, 0)
            if iszero(s1) {
                revert("Token transfer failed")
            }

            // ************
            // calls pair.swap(
            //     tokenOutNo == 0 ? amountOut : 0,
            //     tokenOutNo == 1 ? amountOut : 0,
            //     address(this),
            //     new bytes(0)
            // )
            mstore(0x7c, PAIR_SWAP_ID)
            mstore(
                0x80,
                (tokenOutNo == 0 ? amountOut : 0) | (tokenOutNo == 1 ? amountOut << 128 : 0)
            )
            mstore(0xc0, address())
            mstore(0xe0, 0x80)

            let s2 := call(sub(gas(), 5000), pair, 0, 0x7c, 0xa4, 0, 0)
            if iszero(s2) {
                revert("Swap failed")
            }

            // Emit event for successful swap execution
            log3(
                0x00, 0x60,                   // Memory offset and length
                keccak256("SwapExecuted(address,address,uint128,uint128,uint8)"),
                token, pair, amountIn, amountOut, tokenOutNo
            )
        }
    }
}

