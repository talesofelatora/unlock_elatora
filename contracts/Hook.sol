// SPDX-License-Identifier: MIT
pragma solidity >=0.5.17 <0.9.0;

import "@unlock-protocol/contracts/dist/PublicLock/IPublicLockV10.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "hardhat/console.sol";
import "./Layer.sol";
import { BokkyPooBahsDateTimeLibrary } from "./BokkyPooBahsDateTimeLibrary.sol";

/**
 * @notice Functions to be implemented by a tokenURIHook.
 * @dev Lock hooks are configured on the lock contract by calling `setEventHooks` on the lock.
 */
contract Hook {
    address public _avatarLock;
    address public _buntaiLock;
    address public _gundanLock;
    address public _mappingContract;
    string public _avatarIpfsHash;
    string public _buntaiWeaponIpfsHash;
    string public _gundanWeaponIpfsHash;
    uint public _totalBuntaiWeapons;
    uint public _totalGundanWeapons;

    /**
     * The hook is initialized with each lock contract as well as each layer contract
     */
    constructor(
        address avatarLock,
        address buntaiLock,
        address gundanLock,
        address mappingContract,
        string memory avatarIpfsHash,
        string memory buntaiWeaponIpfsHash,
        string memory gundanWeaponIpfsHash,
        uint totalBuntaiWeapons,
        uint totalGundanWeapons
    ) {
        _avatarLock = avatarLock;
        _buntaiLock = buntaiLock;
        _gundanLock = gundanLock;
        _mappingContract = mappingContract;
        _avatarIpfsHash = avatarIpfsHash;
        _buntaiWeaponIpfsHash = buntaiWeaponIpfsHash;
        _gundanWeaponIpfsHash = gundanWeaponIpfsHash;
        _totalBuntaiWeapons = totalBuntaiWeapons;
        _totalGundanWeapons = totalGundanWeapons;
    }

    /**
     * Not altering the price by default
     */
    function keyPurchasePrice(
        address, /* from */
        address, /* recipient */
        address, /* referrer */
        bytes calldata /* data */
    ) external view returns (uint256 minKeyPrice) {
        // TODO Let's look at the list? 
        return IPublicLock(msg.sender).keyPrice();
    }

    /**
     * When a new key is purchased, we need to grant a weapon
     * Challenge: we
     */
    function onKeyPurchase(
        address, /*from*/
        address recipient,
        address, /*referrer*/
        bytes calldata, /*data*/
        uint256, /*minKeyPrice*/
        uint256 /*pricePaid*/
    ) external {
        if (msg.sender == _avatarLock) {
            // If the sender is the avatar lock
            IPublicLock avatar = IPublicLock(_avatarLock);
            uint id = avatar.totalSupply();

            address[] memory recipients = new address[](1);
            recipients[0] = recipient;

            uint[] memory expirations = new uint[](1);
            expirations[0] = type(uint256).max; // Not expiring!

            address[] memory managers = new address[](1);
            managers[0] = recipient;

            if (id % 2 == 0) {
                IPublicLock(_buntaiLock).grantKeys(recipients, expirations, managers);
            } else {
                IPublicLock(_gundanLock).grantKeys(recipients, expirations, managers);
            }
        }
    }

    
    // see https://github.com/unlock-protocol/unlock/blob/master/smart-contracts/contracts/interfaces/hooks/IHook.sol
    function tokenURI(
        address lockAddress,
        address, // operator, // We could alter the rendering based on _who_ is viewing!
        address owner,
        uint256 keyId,
        uint256  //expirationTimestamp //  a cool trick could be to render based on how far the expiration of the key is!
    ) external view returns (string memory) {
        require(owner != address(0), "Not owned...");

        string memory image = "";
        string memory kind = "";
        string memory moment = "night";
        uint weapon = 0;

        if (lockAddress == _buntaiLock) {
            kind = "buntai";
            weapon = keyId % _totalBuntaiWeapons;
            // Loop back when modulo is 0!
            if (weapon == 0) {
                weapon = _totalBuntaiWeapons;
            }
            image = string(
                abi.encodePacked(
                    _buntaiWeaponIpfsHash,
                    "/",
                    Strings.toString(weapon),
                    ".svg"
                )
            );
        } else if (lockAddress == _gundanLock) {
            kind = "gundan";
            weapon = keyId % _totalGundanWeapons;
            // Loop back when modulo is 0!
            if (weapon == 0) {
                weapon = _totalGundanWeapons;
            }
            image = string(
                abi.encodePacked(
                    _gundanWeaponIpfsHash,
                    "/",
                    Strings.toString(weapon),
                    ".svg"
                )
            );
        } else if (lockAddress == _avatarLock) {
            uint timeOfDay = 0;
            (, , , uint hour, , ) = BokkyPooBahsDateTimeLibrary.timestampToDateTime(block.timestamp);
            if (hour <= 8) {
                timeOfDay = 0; // 0 => night
            } else if (hour <= 17) {
                timeOfDay = 1; // 1 => day
                moment = "day";
            } else if (hour <= 21) {
                timeOfDay = 2; // 2 => sunset
                moment = "sunset";
            } else {
                timeOfDay = 0; // 0 => night
            }

            // TODO: support for explicit mapping!
            if (keyId % 2 == 0) {
                kind = "buntai";
                IPublicLock buntaiContract = IPublicLock(_buntaiLock);
                if (buntaiContract.ownerOf(keyId/2) == owner) {
                    weapon = keyId/2 % _totalBuntaiWeapons;
                    // Loop back when modulo is 0!
                    if (weapon == 0) {
                        weapon = _totalBuntaiWeapons;
                    }
                }
            } else {
                kind = "gundan";
                IPublicLock gundanContract = IPublicLock(_gundanLock);
                if (gundanContract.ownerOf((keyId + 1)/2) == owner) {
                    weapon = ((keyId + 1)/2) % _totalGundanWeapons;
                    // Loop back when modulo is 0!
                    if (weapon == 0) {
                        weapon = _totalGundanWeapons;
                    }
                }
            }

            image = string(
                abi.encodePacked(
                    _avatarIpfsHash,
                    "/",
                    Strings.toString(keyId),
                    "-",
                    Strings.toString(weapon),
                    "-",
                    Strings.toString(timeOfDay),
                    ".svg"
                )
            );
        }

        // create the json that includes the image
        // We need to include more properties!
        string memory json = string(
            abi.encodePacked('{ "image": "', image, '", "attributes": [ {"trait_type": "faction", "value": "', kind,'"}, {"trait_type": "momentOfDay", "value": "', moment,'"},  {"trait_type": "weapon", "value": "', Strings.toString(weapon),'"}], "description": "Tales of Elatora is a community-driven fantasy world, written novel and an RPG. This ToE NFT grants access to the story, the game, the community and gives the holder voting rights. https://talesofelatora.com/", "external_url":"https://talesofelatora.com/", "name": "Tales of Elatora - Avatar"}')
        );

        // render the base64 encoded json metadata
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(bytes(abi.encodePacked(json)))
                )
            );
    }
}
