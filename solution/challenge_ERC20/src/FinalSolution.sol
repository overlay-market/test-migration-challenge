// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

error Claim_Only_Guardian();
error Claim_Invalid_Signature();
error Claim_Must_Have_Admin_Role();
error Claim_Amount_Must_Be_Above_0();
error Claim_Contract_Does_Not_Have_Enough_Tokens();
error Claim_Invalid_Recipient_Address();
error Claim_Signature_Already_Used();

contract Claim is AccessControlEnumerable {
    using ECDSA for bytes32;

    IERC20 public token;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    mapping(bytes32 => bool) public usedSignatures;

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyGuardian() {
        if (!hasRole(GUARDIAN_ROLE, msg.sender)) revert Claim_Only_Guardian();
        _;
    }

    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender))
            revert Claim_Must_Have_Admin_Role();
        _;
    }

    modifier onlyWhenContractHasEnoughTokens(uint256 _amount) {
        if (token.balanceOf(address(this)) < _amount)
            revert Claim_Contract_Does_Not_Have_Enough_Tokens();
        _;
    }

    function grantNewRole(address account, bytes32 _role) external onlyAdmin {
        grantRole(_role, account);
    }

    function revokeExistingRole(
        address account,
        bytes32 _role
    ) external onlyAdmin {
        revokeRole(_role, account);
    }

    /*
    1) This function does not respect Checks Effects Interaction pattern. 
    Moving the line
    bytes32 messageHash = _messageHash.toEthSignedMessageHash(); before the check 
    if (_amount == 0) revert Claim_Amount_Must_Be_Above_0(); 
    would avoid unnecessarily wasting gas if the _amount is equal to 0.
    So it's better to put it first if (_amount == 0) revert Claim_Amount_Must_Be_Above_0();
    and then bytes32 messageHash = _messageHash.toEthSignedMessageHash();

    2) We have to check that _recipient is not an address(O) using this check:
     if (_recipient == address(0)) revert Claim_Invalid_Recipient_Address();
    By validating for a zero address in this way, we can prevent the function 
    from performing unexpected or erroneous behavior, such as transferring tokens 
    to a nonexistent or invalid Ethereum address.

    3) It is possible for a user to reuse the same signature and claim the 
    same _amount multiple times. 
    This is because the contract does not keep track of used signatures or 
    limit the number of times a specific signature can be used.
    To prevent this, you can implement a mechanism to keep track of used 
    signatures and ensure that each signature can only be used once.
    Here's a example:
     a) Maintain a mapping of used signatures:
        mapping(bytes32 => bool) public usedSignatures;
     b) Check whether the signature has already been used:
        if (usedSignatures[messageHash]) revert Claim_Signature_Already_Used();
        and then mark the signature as used:
        usedSignatures[_messageHash] = true;
    
     */

    // Final solution:
    function claimToken(
        uint256 _amount,
        address _recipient,
        bytes32 _messageHash,
        bytes memory _signature
    ) external onlyWhenContractHasEnoughTokens(_amount) {
        if (_amount == 0) revert Claim_Amount_Must_Be_Above_0();
        if (_recipient == address(0)) revert Claim_Invalid_Recipient_Address();
        bytes32 messageHash = _messageHash.toEthSignedMessageHash();

        // Verify the signature
        address signer = messageHash.recover(_signature);
        if (!hasRole(SIGNER_ROLE, signer)) revert Claim_Invalid_Signature();

        if (usedSignatures[messageHash]) revert Claim_Signature_Already_Used();
        usedSignatures[messageHash] = true;

        token.transfer(_recipient, _amount);
    }

    function withdrawToken(
        address _recipient,
        uint256 _amount
    ) external onlyGuardian onlyWhenContractHasEnoughTokens(_amount) {
        token.transfer(_recipient, _amount);
    }
}
