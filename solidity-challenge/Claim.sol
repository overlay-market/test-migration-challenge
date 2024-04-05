// VULNERABILITIES FOUND /////////////////////////////////////////////////////////////////////////////////////
    
    // ***Vulnerability 1: Fraudulent variable editing
    // Exploit:
    //  The user can set the transaction gas really low on metamask for the transaction to be reverted
    //  Then go to etherscan and take the messageHash and signature from failed tx, and resend a new tx with fraudulent recipe and amount variables.
    // Possible solution:
    //   Adds the variables to the message on the backend, and checking them inside the contract, reverting the non compliant tx with fraudulent variables. 


    // ***Vulnerability 2: Fraudulent Duplicate transactions
    // Exploit:
    //  A user can execute multiple txs 
    //  The .recover OZ function allows the signature to be formatted as 64 bytes (EIP-2098) or 65 bytes.
    // allowing one tx with the same params to be sucessfully executed two times if we use the signature as the identifer for replay attacks.
    // Possible solutions:
    //  Implement a internal check by storing the used hashes on the contract, instead of signatures.
    //  Add a nonce variable to function and message, with an internal contract check to revert non compliant messageHashes (enabling safe txs with same params).


    // ***Vulnerability 3: Wrong signatures
    //   The recover function return an zero address when the _signature is not a valid signature for _messageHash
    // Possible solution:
    // Implement a more robust internal check to ensure transaction will revert for unvalid signatures

    // OBSERVATIONS:
    // The provided solutions are not the most efficient in terms of gas and storage
    // There is another smart way of implementing that involve a more web2 approach, and maybe it is outside of the scope of this test.
    // But i can explain it briefly, just in case:
    // 0) We can use a Bitmap, a Merkle Tree proof system, and a single array of 1 and 0s to check for the validity of the claims
    //    - We can have on our backend, the allowed _amount, _recipients, and a index for each claimer, hash them individually (leafs), and derive a root bitmap merkle tree proof that takes into account all of possible claims, and store the root proof inside the contract.
    //    - The Merkle Tree algo have a property were we can prove a signature against the root merkle tree proof by providing the other needed claim leafs in a O(log(n)) manner, were n is the number of leafs/claims.  
    //    - Then, when sending the transactions on our FE, given the user infos, we will provide the other needed leafs that are necessary to prove the current tx against the root proof, and send them accordly with the tx (we can do this in the web2 backend+frontend)
    //    - OpenZeppelin have this implementation padronized with the @openzeppelin/contracts/utils/structs/BitMaps.sol and @openzeppelin/contracts/utils/cryptography/MerkleProof.sol contracts.


// WEB2 / MERKLE TREE / BITMAP IMPLEMENTATION ///////////////////////////////////////////////////////////////////////////////////////////////////
pragma solidity 0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Claim is ERC20 {
    bytes32 public immutable merkleRoot;
    BitMaps.BitMap private _claimList;

    constructor(bytes32 _merkleRoot) ERC20("Token", "TOK") {
        merkleRoot = _merkleRoot;
    }

    function claim(bytes32[] calldata proof, uint256 index, uint256 amount) external {
        // check if already claimed
        require(!BitMaps.get(_claimList, index), "Already claimed");

        // verify proof
        _verifyProof(proof, index, amount, msg.sender);

        // set as claimed
        BitMaps.setTo(_claimList, index, true);

        // mint tokens
        _mint(msg.sender, amount);
    }

    function _verifyProof(bytes32[] memory proof, uint256 index, uint256 amount, address addr) private view {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(addr, index, amount))));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");
    }
}

// DEFAULT IMPLEMENTATION /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// There is a know High severity ECDSA signature malleability vulnerability (more details at OpenZeppelin GH repo. (versions >= 4.1.0 < 4.7.3))
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

error Claim_Only_Guardian();
error Claim_Invalid_Signature();
error Claim_Must_Have_Admin_Role();
error Claim_Amount_Must_Be_Above_0();
error Claim_Contract_Does_Not_Have_Enough_Tokens();

contract Claim is AccessControlEnumerable {
    using ECDSA for bytes32;

    IERC20 public token;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    
    // Fix Vulnerability 2:********************************************
    mapping(bytes32 => bool) public usedHashes;
    //*****************************************************************

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

    function claimToken(
        uint256 _amount,
        address _recipient,
        bytes32 _messageHash,
        uint256 _nonce,
        bytes memory _signature
    ) external onlyWhenContractHasEnoughTokens(_amount) {
        // Fix Vulnerability 1 and 2:********************************************
        bytes32 messageHash = keccak256(abi.encodePacked(_amount, _recipient, _nonce)).toEthSignedMessageHash();
        require(messageHash == _messageHash, "The message hash does not match the original amount, recipient and nonce values");
        //*****************************************************************

        // Fix Vulnerability 2:********************************************
        require(!usedHashes[messageHash], "This message hash has already been used");
        //*****************************************************************

        if (_amount == 0) revert Claim_Amount_Must_Be_Above_0();

        // Fix Vulnerability 3:********************************************
        (address signer, ECDSA.RecoverError error, ) = messageHash.recover(_signature);
        require(error == ECDSA.RecoverError.NoError, "Invalid signature");
        //*****************************************************************

        if (!hasRole(SIGNER_ROLE, signer)) revert Claim_Invalid_Signature();
        
        // Fix Vulnerability 2:********************************************
        usedHashes[messageHash] = true;
        //*****************************************************************

        token.transfer(_recipient, _amount);
    }

    function withdrawToken(
        address _recipient,
        uint256 _amount
    ) external onlyGuardian onlyWhenContractHasEnoughTokens(_amount) {
        token.transfer(_recipient,_amount);
    }
}