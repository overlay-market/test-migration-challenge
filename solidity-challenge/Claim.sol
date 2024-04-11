pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

error Claim_Only_Guardian();
error Claim_Invalid_Signature();
error Claim_Must_Have_Admin_Role();
error Claim_Amount_Must_Be_Above_0();
error Claim_Contract_Does_Not_Have_Enough_Tokens();
error Invalid_Nonce();
error Expired_Claim();

contract Claim is AccessControlEnumerable {
    using ECDSA for bytes32;

    IERC20 public token;

    // address to nonce
    uint256 public currentNonce;

    bytes32 public constant  DATA_TYPE_HASH = keccak256("claimToken(uint256 _amount,address _recipient,uint256 _nonce,bytes _signature)");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyGuardian() {
        if (!hasRole(GUARDIAN_ROLE, msg.sender)) revert
        Claim_Only_Guardian();
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

    /**
    * The `claimToken` function is prone to replay and cross-chain replay attacks.
    * If a user gains access to the signature, this attack can be replayed across different EVM chains.
    * One way to prevent cross-chain replay attacks is to introduce the `chainId`. By doing this, if someone tries to `claimToken` on a different chain, the transaction will revert with the error 'Claim_Invalid_Signature'.
    * Initially, we check the currentNonce, timestamp, _amount and chainId. If any of these fail, the transaction will revert.
    * Upon successful passing of the first four checks, we get the signer. If the signer does not have the 'SIGNER_ROLE', the transaction will revert with 'Claim_Invalid_Signature'.
    * Once all checks have passed, we update the nonce of this contract and transfer the asset to the '_recipient'.
    */
    function claimToken(
        uint256 _amount,
        address _recipient,
        uint256 _nonce,
        uint256 _deadline,
        uint256 _chainId,
        bytes calldata _signature
    ) external onlyWhenContractHasEnoughTokens(_amount) {
        if (currentNonce != _nonce) revert Invalid_Nonce();
        if (block.timestamp > _deadline) revert Expired_Claim();
        if (_amount == 0) revert Claim_Amount_Must_Be_Above_0();
        if (_chainId != block.chainid) revert  Invalid_Chain_ID();();
        bytes32 _messageHash = keccak256(abi.encode(DATA_TYPE_HASH, _recipient, _amount, _nonce, _deadline, _chainId, address(token)));
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(keccak256(abi.encodePacked(_messageHash, _nonce)));
        // Verify the signature
        address signer = messageHash.recover(_signature);
        if (!hasRole(SIGNER_ROLE, signer)) revert Claim_Invalid_Signature();
        currentNonce++;
        token.transfer(_recipient, _amount);
    }

    function withdrawToken(
        address _recipient,
        uint256 _amount
    ) external onlyGuardian onlyWhenContractHasEnoughTokens(_amount) {
        token.transfer(_recipient,_amount);
    }
}