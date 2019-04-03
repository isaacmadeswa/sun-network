pragma solidity ^0.4.24;

import "../common/token/TRC20/ITRC20Receiver.sol";
import "../common/token/TRC721/ITRC721Receiver.sol";
import "./DAppTRC20.sol";
import "./DAppTRC721.sol";

contract Gateway is ITRC20Receiver, ITRC721Receiver {

    // 1. deployDAppTRC20AndMapping
    // 2. deployDAppTRC721AndMapping
    // 3. depositTRC10
    // 4. depositTRC20
    // 5. depositTRC721
    // 6. depositTRX
    // 7. withdrawTRC10
    // 8. withdrawTRC20
    // 9. withdrawTRC721
    // 10. withdrawTRX


    event DeployDAppTRC20AndMapping(address developer, address mainChainAddress, address sideChainAddress);
    event DeployDAppTRC721AndMapping(address developer, address mainChainAddress, address sideChainAddress);
    event DepositTRC10(address to, uint256 trc10, uint256 value, address sideChainAddress);
    event DepositTRC20(address sideChainAddress, address to, uint256 value);
    event DepositTRC721(address sideChainAddress, address to, uint256 tokenId);
    event DepositTRX(address to, uint256 value);
    event WithdrawTRC10(address from, uint256 value, uint256 trc10, bytes memory txData);
    event WithdrawTRC20(address from, uint256 value, address mainChainAddress, bytes memory txData);
    event WithdrawTRC721(address from, uint256 tokenId, address mainChainAddress, bytes memory txData);
    event WithdrawTRX(address from, uint256 value, bytes memory txData);

    // TODO: type enum
    mapping(address => address) mainToSideContractMap;
    mapping(address => address) sideToMainContractMap;
    mapping(uint256 => address) mainToSideTRC10Map;
    mapping(address => uint256) sideToMainTRC10Map;
    address oracle;
    address mintTRXContract = 0x00;

    constructor () public {

    }

    // TODO: modify oracle
    modifier onlyOracle {
        require(msg.sender == oracle);
        _;
    }

    // 1. deployDAppTRC20AndMapping
    function deployDAppTRC20AndMapping(bytes txId, string name, string symbol, uint8 decimals) public {
        // can be called by everyone (contract developer)
        address mainChainAddress = calcContractAddress(txId, msg.sender);
        require(mainToSideContractMap[mainChainAddress] == address(0), "the main chain address has mapped");
        address sideChainAddress = new DAppTRC20(address(this), name, symbol, decimals);
        mainToSideContractMap[mainChainAddress] = sideChainAddress;
        sideToMainContractMap[sideChainAddress] = mainChainAddress;
        emit DeployDAppTRC20AndMapping(msg.sender, mainChainAddress, sideChainAddress);
    }

    // 2. deployDAppTRC721AndMapping
    function deployDAppTRC721AndMapping(bytes txId, string name, string symbol) public {
        // can be called by everyone (contract developer)
        address mainChainAddress = calcContractAddress(txId, msg.sender);
        require(mainToSideContractMap[mainChainAddress] == address(0), "the main chain address has mapped");
        address sideChainAddress = new DAppTRC721(address(this), name, symbol);
        mainToSideContractMap[mainChainAddress] = sideChainAddress;
        sideToMainContractMap[sideChainAddress] = mainChainAddress;
        emit DeployDAppTRC721AndMapping(msg.sender, mainChainAddress, sideChainAddress);
    }

    // 3. depositTRC10
    function depositTRC10(address to, uint256 trc10, uint256 value) public onlyOracle {
        // can only be called by oracle
        require(trc10 > 0, "trc10 must be greater than 0");
        address sideChainAddress = mainToSideTRC10Map[trc10];
        if (sideChainAddress == address(0)) {
            // TODO: combine
            sideChainAddress = new DAppTRC20(address(this), "TRC10_" + trc10, "TRC10_" + trc10, 6);
            mainToSideTRC10Map[trc10] = sideChainAddress;
            sideToMainTRC10Map[sideChainAddress] = trc10;
        }
        IDApp(sideChainAddress).mint(to, value);
        emit DepositTRC10(to, trc10, value, sideChainAddress);
    }

    // 4. depositTRC20
    function depositTRC20(address to, address mainChainAddress, uint256 value) public onlyOracle {
        // can only be called by oracle
        address sideChainAddress = mainToSideContractMap[mainChainAddress];
        require(sideChainAddress != address(0), "the main chain address hasn't mapped");
        IDApp(sideChainAddress).mint(to, value);
        emit DepositTRC20(sideChainAddress, to, value);
    }

    // 5. depositTRC721
    function depositTRC721(address to, address mainChainAddress, uint256 tokenId) public onlyOracle {
        // can only be called by oracle
        address sideChainAddress = mainToSideContractMap[mainChainAddress];
        require(sideChainAddress != address(0), "the main chain address hasn't mapped");
        IDApp(sideChainAddress).mint(to, tokenId);
        emit DepositTRC721(sideChainAddress, to, tokenId);
    }

    // 6. depositTRX
    function depositTRX(address to, uint256 value) public onlyOracle {
        // can only be called by oracle
        mintTRXContract.call(to, value);
        emit DepositTRX(to, value);
    }

    // 7. withdrawTRC10
    // 8. withdrawTRC20
    function onTRC20Received(address from, uint256 value, bytes memory data) public returns (bytes4) {
        address sideChainAddress = msg.sender;
        address mainChainAddress = sideToMainContractMap[sideChainAddress];
        if (mainChainAddress == address(0)) {
            // TRC10
            // burn
            DAppTRC20(sideChainAddress).transfer(address(0), value);
            uint256 trc10 = sideToMainTRC10Map[sideChainAddress];
            require(trc10 > 0, "the trc10 or trc20 must have been deposited");
            emit WithdrawTRC10(from, value, trc10, txData);
        } else {
            // TRC20
            // burn
            DAppTRC20(sideChainAddress).transfer(address(0), value);
            emit WithdrawTRC20(from, value, mainChainAddress, txData);
        }
        return _TRC20_RECEIVED;
    }

    // 9. withdrawTRC721
    function onTRC721Received(address from, uint256 tokenId, bytes memory data) public returns (bytes4) {
        address sideChainAddress = msg.sender;
        address mainChainAddress = sideToMainContractMap[sideChainAddress];
        require(mainChainAddress != address(0), "the trc721 must have been deposited");
        // burn
        DAppTRC721(sideChainAddress).transfer(address(0), tokenId);
        emit WithdrawTRC721(from, tokenId, mainChainAddress, txData);
        return _TRC721_RECEIVED;
    }

    // 10. withdrawTRX
    function withdrawTRX(bytes memory txData) {
        // burn
        // FIXME in tron side chain: will be fail in tron
        address(0).transfer(msg.value);
        emit WithdrawTRX(msg.sender, msg.value, txData);
    }

    function calcContractAddress(bytes txId, address owner) public pure returns (address r) {
        bytes memory addressBytes = addressToBytes(owner);
        bytes memory combinedBytes = concatBytes(txId, addressBytes);
        r = address(keccak256(combinedBytes));
    }

    function addressToBytes(address a) public pure returns (bytes memory b) {
        assembly {
            let m := mload(0x40)
            a := and(a, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, a))
            mstore(0x40, add(m, 52))
            b := m
        }
    }

    //    function concatBytes(bytes32 b1, bytes32 b2) pure external returns (bytes memory) {
    //        bytes memory result = new bytes(64);
    //        assembly {
    //            mstore(add(result, 32), b1)
    //            mstore(add(result, 64), b2)
    //        }
    //        return result;
    //    }

    function concatBytes(bytes memory b1, bytes memory b2) pure public returns (bytes memory r) {
        r = new bytes(b1.length + b2.length + 1);
        uint256 k = 0;
        for (uint256 i = 0; i < b1.length; i++)
            r[k++] = b1[i];
        r[k++] = 0x41;
        for (i = 0; i < b2.length; i++)
            r[k++] = b2[i];
    }
}