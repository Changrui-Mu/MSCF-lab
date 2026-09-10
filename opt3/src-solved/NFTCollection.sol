// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTCollection is ERC721 {
    struct NFT {
        string name;
        string URI;
    }

    event Mint(uint256 index, address indexed mintedBy);

    NFT[] private allNFTs;

    constructor() ERC721("NFT Collection", "NFTC") {}

    function mintNFT(string memory nftName, string memory nftURI) external returns (uint256) {
        allNFTs.push(NFT({name: nftName, URI: nftURI}));
        uint256 tokenId = allNFTs.length - 1;
        _safeMint(msg.sender, tokenId);
        emit Mint(tokenId, msg.sender);
        return tokenId;
    }

    function transferNFTFrom(address from, address to, uint256 tokenId) public virtual returns (bool) {
        safeTransferFrom(from, to, tokenId);
        return true;
    }
}
