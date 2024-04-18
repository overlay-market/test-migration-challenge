# Solution
## Full repository
Checkout this [repo](https://github.com/MatiArazi/foundry-claim-token-challenge/tree/main) with a complete solution

## Issues
1. Started by moving the if statement where it checks if `_amount == 0` to the top.
2. Then I checked if `_recipient == address(0)`, although it's checked in the transfer, it's better if it's checked before, to avoid unnecessary operations.
3. Additionally, I verified if `_messageHash` is not a random message. Therefore, I declared `bytes32 expectedMessageHash = keccak256(abi.encodePacked(_amount, _recipient))` and compared it with `_messageHash`. They should be equal; if not, it reverts.
4. After all these checks, I proceeded with the function logic, which was already implemented.

## Tests
You can look into the [`./test`](https://github.com/MatiArazi/foundry-claim-token-challenge/blob/main/test) folder and compare the test on both contracts and evidence the issues en `OldClaim` and how they are fixed on `Claim`.
