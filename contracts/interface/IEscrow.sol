// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

interface IEscrow {
    function isRented(address nftAddress, address account, uint256 tokenId, uint256 qty) external view returns(bool);
}
