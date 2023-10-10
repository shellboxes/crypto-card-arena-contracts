// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title Helpers
/// @dev A utility contract that provides signature verification and array manipulation functions.
library Helpers {
    using ECDSA for bytes32;
    /// @dev Checks if a given signature is valid for a specific message hash and signer address.
    /// @param signature The signature to be verified.
    /// @param msgHash The hash of the message that was signed.
    /// @param signer The address of the signer.
    /// @return True if the signature is valid, false otherwise.
    function _validSignature(bytes memory signature, bytes32 msgHash, address signer) internal pure returns (bool) {
        return msgHash.toEthSignedMessageHash().recover(signature) == signer;
    }

    
}