// SPDX-License-Identifier:UNLICENSED
pragma solidity 0.8.13;

import "./interface/ITransferProxy.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract Escrow is ERC721Holder, ERC1155Receiver, ERC1155Holder {

    event Lended(bytes32 id, address lender, address nftAddress, uint256 tokenId, uint256 quantity);

    event Rented(bytes32 id, address renter, address nftAddress, uint256 tokenId, uint256 quantity);

    event Claimed(bytes32 id, address lender, address renter, address nftAddress, uint256 tokenId, uint256 quantity);

    event regained(bytes32 id, address lender, address nftAddress, uint256 tokenId, uint256 quantity);


    struct LendData {
        bytes32 lendId;
        address lender;
        address nftAddress;
        uint256 tokenId;
        uint256 maxduration;
        uint256 dailyRent;
        uint256 lendingQuantity;
        address paymentAddress;
        uint256 lendTime;
    }

    struct RentData {
        bytes32 lendedId;
        address renter;
        address lender;
        address nftAddress;
        uint256 tokenId;
        uint256 duration;
        uint256 rentedQuantity;
        uint256 rentedTime;
    }

    struct Sign {
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 nonce;
    }
    mapping(uint256 => bool) usedNonce;
    mapping(bytes32 => LendData) private lendingDetails;
    mapping(bytes32 => RentData) private rentalDetails;
    mapping(bytes32 => bool) public isValid;
    mapping(address=> mapping(address => mapping(uint256 => uint256))) private rentedQty;
    event OwnershipTransferred(address owner, address newOwner);
    event Signerchanged(address signer, address newSigner);

    address public owner;

    address public signer;

    uint256 public RentalFee;

    ITransferProxy public transferProxy;


    constructor(uint256 _platFee, ITransferProxy _transferProxy) {

        transferProxy = _transferProxy;
        owner = msg.sender;
        signer = msg.sender;
        RentalFee = _platFee;
    }

    function changeSigner(address newSigner) external {
        require(newSigner != address(0), "signer: Invalid Address");
        signer = newSigner;
    }

    function tranferOwnership(address newOwner) external {
        require(newOwner != address(0), "signer: Invalid Address");
        owner = newOwner;
    }

    function setRentalFee(uint256 _platFee) external {
        RentalFee = _platFee;
    }

    function lend(LendData memory lendData, Sign calldata sign) external {
        require(!usedNonce[sign.nonce], "Nonce: invalid nonce");
        usedNonce[sign.nonce] = true;
        require(lendData.maxduration > 0, "Lend: lending duration must be greater than zero");
        require(lendData.dailyRent > 0, "Lend: daily rent must be greater than zero");
        require(lendData.nftAddress != address(0) && lendData.paymentAddress != address(0), "Lend: address should not be zero");
        verifySign(generateId(lendData.lender, lendData.tokenId, lendData.lendingQuantity, lendData.nftAddress, lendData.paymentAddress), msg.sender, sign);
        lendData.lendTime = block.timestamp;
        lendData.lender = msg.sender;
        lendData.lendId = generateId(lendData.lender, lendData.tokenId, lendData.lendingQuantity, lendData.nftAddress, lendData.paymentAddress);
        isValid[lendData.lendId] = true; 
        lendingDetails[lendData.lendId] = lendData;
        uint8 nftType = getValidType(lendData.nftAddress);
        isApproved(nftType, lendData.nftAddress);
        safeTransfer(lendData.nftAddress, lendData.paymentAddress, lendData.lender, address(this), lendData.tokenId, lendData.lendingQuantity, nftType, 0, false);
        emit Lended(lendData.lendId, lendData.lender, lendData.nftAddress, lendData.tokenId, lendData.lendingQuantity);
    }

    function rent(bytes32 lendId, uint256 qty, uint256 duration, Sign calldata sign) external {
        require(!usedNonce[sign.nonce], "Nonce: invalid nonce");
        usedNonce[sign.nonce] = true;
        require(isValid[lendId],"rent: Invalid Id");
        require(duration > 0 && duration <= lendingDetails[lendId].maxduration, "rent: lending duration must be greater than zero or less than max duration");
        verifySign(generateId(msg.sender, lendingDetails[lendId].tokenId, qty, lendingDetails[lendId].nftAddress, lendingDetails[lendId].lender), msg.sender, sign);
        bytes32 rentId = (generateId(msg.sender, lendingDetails[lendId].tokenId, qty, lendingDetails[lendId].nftAddress, lendingDetails[lendId].lender));
        uint8 nftType = getValidType(lendingDetails[lendId].nftAddress);
        isApproved(nftType,lendingDetails[lendId].nftAddress);
        uint256 fee = getFees(lendingDetails[lendId].paymentAddress, lendingDetails[lendId].dailyRent, duration, qty);
        rentalDetails[rentId] = RentData(lendId, msg.sender, lendingDetails[lendId].lender, lendingDetails[lendId].nftAddress, lendingDetails[lendId].tokenId, duration, qty, block.timestamp);
        safeTransfer(lendingDetails[lendId].nftAddress, lendingDetails[lendId].paymentAddress, address(this), msg.sender, lendingDetails[lendId].tokenId, qty, nftType, fee, false);
        rentedQty[msg.sender][lendingDetails[lendId].nftAddress][lendingDetails[lendId].tokenId] = rentedQty[msg.sender][lendingDetails[lendId].nftAddress][lendingDetails[lendId].tokenId] + qty;
        lendingDetails[lendId].lendingQuantity -= qty;
        if(lendingDetails[lendId].lendingQuantity == 0) {isValid[lendId] = false; }
        emit Rented(rentId, lendingDetails[lendId].lender, msg.sender, lendingDetails[lendId].tokenId, qty);
    }

    function claim(bytes32 rentalId, Sign calldata sign) external {
        require(!usedNonce[sign.nonce], "Nonce: invalid nonce");
        usedNonce[sign.nonce] = true;
        verifySign(rentalId, msg.sender, sign);
        isExpired(rentalId);
        bytes32 lendId = rentalDetails[rentalId].lendedId;
        require(msg.sender == rentalDetails[rentalId].lender);
        rentedQty[rentalDetails[rentalId].renter][rentalDetails[rentalId].nftAddress][rentalDetails[rentalId].tokenId] -= rentalDetails[rentalId].rentedQuantity;
        uint8 nftType = getValidType(lendingDetails[lendId].nftAddress); 
        uint256 fee = getFees(lendingDetails[lendId].paymentAddress, lendingDetails[lendId].dailyRent, rentalDetails[rentalId].duration, rentalDetails[rentalId].rentedQuantity);
        require(IERC20(lendingDetails[lendId].paymentAddress).approve(address(transferProxy), fee),"IERC20: failed on Approval");
        safeTransfer(lendingDetails[lendId].nftAddress, lendingDetails[lendId].paymentAddress, rentalDetails[rentalId].renter, rentalDetails[rentalId].lender, rentalDetails[rentalId].tokenId, rentalDetails[rentalId].rentedQuantity, nftType, fee, true);
        if(lendingDetails[lendId].lendingQuantity == 0) isValid[lendId] = false;
        isValid[rentalId] = false;
        emit Claimed(rentalId, rentalDetails[rentalId].lender, rentalDetails[rentalId].renter, lendingDetails[lendId].nftAddress, rentalDetails[rentalId].tokenId, rentalDetails[rentalId].rentedQuantity);
    }

    function regain(bytes32 lendId, Sign calldata sign) external {
        require(isValid[lendId],"retain: Invalid Id");
        require(!usedNonce[sign.nonce], "Nonce: invalid nonce");
        usedNonce[sign.nonce] = true;
        verifySign(lendId, msg.sender, sign);
        require(msg.sender == lendingDetails[lendId].lender, "retain: caller doesn't have role");
        uint8 nftType = getValidType(lendingDetails[lendId].nftAddress);
        isApproved(nftType,lendingDetails[lendId].nftAddress);
        safeTransfer(lendingDetails[lendId].nftAddress, lendingDetails[lendId].paymentAddress, address(this), lendingDetails[lendId].lender,lendingDetails[lendId].tokenId, lendingDetails[lendId].lendingQuantity, nftType, 0, false);
        isValid[lendId] = false;
    }

    function isRented(address nftAddress, address account, uint256 tokenId, uint256 qty) external view returns(bool) {
        uint256 _rentedQty = rentedQty[account][nftAddress][tokenId];
        uint256 nftType = getValidType(nftAddress);
        if(nftType == 0) {
            return _rentedQty == 1;
        }
        if(nftType == 1 ) {
            uint256 balance = IERC1155(nftAddress).balanceOf(account, tokenId);
            if((balance - _rentedQty) >= qty)
            {
                return true;
            }
            else {
                return false;
            }
        }
        return false;
    }

        // bytes32 lendId;
        // address lender;
        // address nftAddress;
        // uint256 tokenId;
        // uint256 maxduration;
        // uint256 dailyRent;
        // uint256 lendingQuantity;
        // address paymentAddress;
        // uint256 lendTime;

    function getLendDetails(bytes32 id) external view returns(LendData memory, bool) {
        return (lendingDetails[id], isValid[id]);
    }
    
    function getrentDetails(bytes32 id) external view returns(RentData memory, bool) {
        return (rentalDetails[id], isValid[id]);
    }

    function generateId(address account, uint256 tokenId, uint256 qty, address nftAddress, address keyAddress) internal pure returns(bytes32 meomory){
        return keccak256(abi.encodePacked(account, tokenId, qty, nftAddress, keyAddress));
    }

    function getValidType(address nftAddress) internal view returns(uint8) {
        if (IERC165(nftAddress).supportsInterface(type(IERC721).interfaceId)) return 0;
        if (IERC165(nftAddress).supportsInterface(type(IERC1155).interfaceId)) return 1;
        return 99;
    }

    function isApproved(uint8 _type, address nftAddress) internal {
        
        if(_type == 0) {
            if(!IERC721(nftAddress).isApprovedForAll(address(this), address(transferProxy))) {
                IERC721(nftAddress).setApprovalForAll(address(transferProxy), true);
            }
        }
        if(_type == 1) {
            if(!IERC1155(nftAddress).isApprovedForAll(address(this), address(transferProxy))) {
                IERC1155(nftAddress).setApprovalForAll(address(transferProxy), true);
            }
        }
    }

    function safeTransfer(address nftAddress, address paymentAddress, address caller, address callee, uint256 tokenId, uint256 lendingAmount, uint8 nftType, uint256 amount, bool isClaim) internal {
        if(nftType == 0) {
            transferProxy.erc721safeTransferFrom(IERC721(nftAddress) , caller, callee, tokenId);
        }

        if(nftType == 1) {
            transferProxy.erc1155safeTransferFrom(IERC1155(nftAddress), caller, callee, tokenId, lendingAmount, "");
        }

        if(amount > 0) {
            if(isClaim) { 
                caller = msg.sender; 
                callee = address(this);
                uint256 fee = amount * RentalFee / 1000;
                amount -=fee;
                if( fee > 0) {
                transferProxy.erc20safeTransferFrom(IERC20(paymentAddress), callee, owner, fee);
                }

            }
            transferProxy.erc20safeTransferFrom(IERC20(paymentAddress), callee, caller, amount);
        }
    }

    function getFees(address token, uint256 dailyRent, uint256 duration, uint256 qty) internal view returns(uint256) {
       return (dailyRent * duration * qty) * 10 ** IERC20Metadata(token).decimals();
    }

    function isExpired(bytes32 rentId) internal view {
        require(rentalDetails[rentId].rentedTime + ((rentalDetails[rentId].duration) * 1 seconds) <= block.timestamp, "time not exceeds");
    }

    function verifySign(
        bytes32 id,
        address caller,
        Sign memory sign
    ) internal view {

        bytes32 hash = keccak256(
            abi.encodePacked(this, caller, id, sign.nonce)
        );
        require(
            owner ==
                ecrecover(
                    keccak256(
                        abi.encodePacked(
                            "\x19Ethereum Signed Message:\n32",
                            hash
                        )
                    ),
                    sign.v,
                    sign.r,
                    sign.s
                ),
            "Owner sign verification failed"
        );
    }

}