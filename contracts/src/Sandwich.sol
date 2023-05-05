// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "./interface/IERC20.sol";
import "./lib/SafeTransfer.sol";

contract Sandwich {
    using SafeTransfer for IERC20;

    // Authorized user (updated to be mutable)
    address private user;

    // transfer(address,uint256) function signature
    bytes4 private constant ERC20_TRANSFER_ID = 0xa9059cbb;

    // swap(uint256,uint256,address,bytes) function signature
    bytes4 private constant PAIR_SWAP_ID = 0x022c0d9f;

    // Events
    event RecoveredERC20(address token, address user, uint256 amount);
    event RecoveredETH(address user, uint256 amount);
    event SwapExecuted(address token, address pair, uint128 amountIn, uint128 amountOut, uint8 tokenOutNo);
    event UserUpdated(address oldUser, address newUser);

    // Constructor sets the initial user
    constructor(address _owner) {
        user = _owner;
    }

    // Receive ETH
    receive() external payable {}

    // Function to recover ERC20 tokens from the contract
    function recoverERC20(address token) external onlyUser {
        uint256 amount = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(msg.sender, amount);
        emit RecoveredERC20(token, msg.sender, amount);
    }

    // Function to recover Ether from the contract
    function recoverETH() external onlyUser {
        uint256 amount = address(this).balance;
        payable(msg.sender).transfer(amount);
        emit RecoveredETH(msg.sender, amount);
    }

    // Function to update the authorized user
    function updateUser(address newUser) external onlyUser {
        require(newUser != address(0), "Invalid new user");
        emit UserUpdated(user, newUser);
        user = newUser;
    }

    // Modifier to restrict access to the authorized user
    modifier onlyUser() {
        require(msg.sender == user, "Unauthorized");
        _;
    }

    // Fallback function for frontslice and backslice
    fallback() external payable onlyUser {
        // Assembly cannot read immutable variables
        address memUser = user;

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

