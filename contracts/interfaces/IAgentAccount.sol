// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IAgentAccount
/// @notice An ERC-6551 token-bound account made usable by an ERC-4337 bundler.
///
/// The account is owned by an NFT, so transferring the token transfers control of the
/// wallet in one transaction with no key handover. That NFT is the agent's entry in an
/// ERC-8004 identity registry.
///
/// ERC-6551 says nothing about ERC-4337. A bundler will not touch an account that does
/// not implement `validateUserOp`, so this interface adds it, and routes the decision to
/// an installed validator module rather than hard-coding policy. See D-001 and D-004.
interface IAgentAccount {
    // --------------------------------------------------------------- errors

    /// @dev Thrown when a UserOperation arrives before any validator is installed.
    ///      The 6551 registry hands out a deterministic address immediately, so an
    ///      account can exist and be unable to authorise anything. That state is real
    ///      and is rejected explicitly rather than falling through to owner-only.
    error NoValidatorInstalled();

    error NotEntryPoint(address caller);
    error NotTokenOwner(address caller);
    error ValidatorAlreadyInstalled(address validator);
    error ValidatorNotInstalled(address validator);
    error LastValidatorRemoved();

    // --------------------------------------------------------------- events

    event ValidatorInstalled(address indexed validator, bytes initData);
    event ValidatorUninstalled(address indexed validator);
    event Executed(address indexed target, uint256 value, bytes4 selector);

    // ------------------------------------------------------------- identity

    /// @notice The NFT that owns this account, per ERC-6551.
    /// @return chainId       Chain the token lives on.
    /// @return tokenContract Registry holding the agent's identity NFT.
    /// @return tokenId       The agent's id.
    function token()
        external
        view
        returns (uint256 chainId, address tokenContract, uint256 tokenId);

    /// @notice Monotonic counter bumped on every state-changing call.
    /// @dev Part of ERC-6551. Included in the signed payload so a signature cannot be
    ///      replayed against the same account after its state has moved on.
    function state() external view returns (uint256);

    /// @notice Current holder of the identity NFT. Ownership follows the token.
    function owner() external view returns (address);

    // -------------------------------------------------------------- modules

    /// @notice Install a validator. Owner only.
    /// @dev The first validator is what makes the account usable by a bundler at all.
    ///      Until then `validateUserOp` reverts with NoValidatorInstalled.
    function installValidator(address validator, bytes calldata initData) external;

    /// @notice Remove a validator. Owner only.
    /// @dev Reverts with LastValidatorRemoved if it would leave the account with none.
    ///      An account that cannot validate is not recoverable through the 4337 path,
    ///      only through the token owner, and that asymmetry should be deliberate rather
    ///      than reachable by accident.
    function uninstallValidator(address validator) external;

    function isValidatorInstalled(address validator) external view returns (bool);

    function validators() external view returns (address[] memory);

    // ----------------------------------------------------------- validation

    /// @notice ERC-4337 entry point for validation.
    /// @dev EntryPoint only. The first 20 bytes of `signature` name the validator to
    ///      route to; the remainder is passed through to it. Returns the module's packed
    ///      validationData unchanged, so time bounds survive to the EntryPoint and an
    ///      expired operation is rejected during simulation rather than on chain.
    function validateUserOp(
        bytes32 userOpHash,
        bytes calldata signature,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData);

    // ------------------------------------------------------------ execution

    /// @notice Execute a call. EntryPoint or token owner only.
    /// @dev On the EntryPoint path the account reports spend back to the validator that
    ///      authorised the call, after execution succeeds. Reporting before execution
    ///      would charge budget for operations that revert.
    function execute(address target, uint256 value, bytes calldata data)
        external
        payable
        returns (bytes memory result);
}
