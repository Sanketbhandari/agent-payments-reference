// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ISessionKeyValidator
/// @notice A validator module that grants an agent bounded authority over an account.
///
/// The account itself holds no policy. It delegates validation to a module installed
/// against it, so authority can be narrowed, extended or revoked without touching the
/// account or moving funds. See docs/adr/D-003.
///
/// Shaped as an ERC-7579 module of type 1 (validator) so it can be installed on any
/// account implementing that standard, including an ERC-6551 token-bound account that
/// has been made 4337-compatible.
interface ISessionKeyValidator {
    // ---------------------------------------------------------------- types

    /// @param signer         Key permitted to sign on the account's behalf.
    /// @param validAfter     Unix seconds. Not valid before this.
    /// @param validUntil     Unix seconds. Not valid after this. Zero is rejected on
    ///                       install: a key with no expiry is the thing this exists to prevent.
    /// @param spendLimitWei  Cumulative ceiling in wei over the key's whole lifetime,
    ///                       not per transaction and not per window.
    /// @param spentWei       Consumed so far. Monotonic. Never reset.
    struct SessionKey {
        address signer;
        uint48 validAfter;
        uint48 validUntil;
        uint256 spendLimitWei;
        uint256 spentWei;
    }

    // --------------------------------------------------------------- events

    event SessionKeyInstalled(
        address indexed account,
        address indexed signer,
        uint48 validAfter,
        uint48 validUntil,
        uint256 spendLimitWei
    );

    event SessionKeyRevoked(address indexed account, address indexed signer);

    event SpendRecorded(
        address indexed account,
        address indexed signer,
        uint256 amountWei,
        uint256 spentWeiTotal
    );

    // --------------------------------------------------------------- errors

    error KeyAlreadyInstalled(address account, address signer);
    error KeyNotInstalled(address account, address signer);
    error ExpiryRequired();
    error ExpiryInPast(uint48 validUntil);
    error WindowInverted(uint48 validAfter, uint48 validUntil);
    error SpendLimitExceeded(uint256 requested, uint256 remaining);
    error TargetNotPermitted(address target);
    error SelectorNotPermitted(bytes4 selector);

    // ------------------------------------------------------------ lifecycle

    /// @notice Install a session key against msg.sender.
    /// @dev Reverts if validUntil is zero or already past, or if validAfter is not
    ///      strictly before validUntil. Callable only by the account.
    /// @param key      Signer, window and cumulative spend ceiling.
    /// @param targets  Contracts the key may call. Empty means none, not all.
    /// @param selectors Function selectors the key may invoke on those targets.
    function installSessionKey(
        SessionKey calldata key,
        address[] calldata targets,
        bytes4[] calldata selectors
    ) external;

    /// @notice Revoke a key immediately. Idempotent from the caller's perspective is
    ///         deliberately NOT offered: revoking an absent key reverts, so a failed
    ///         revocation is visible rather than silently successful.
    function revokeSessionKey(address signer) external;

    // ----------------------------------------------------------- validation

    /// @notice Validate a signature and the operation it authorises.
    /// @dev Returns ERC-4337 packed validationData:
    ///      `validAfter << 208 | validUntil << 160 | authorizer`, where authorizer is
    ///      address(0) on success and address(1) on signature failure. Returning the
    ///      time bounds rather than reverting lets the EntryPoint reject an expired
    ///      operation during simulation, before it is bundled.
    /// @param account   Account the operation runs against.
    /// @param userOpHash Hash the session key signed.
    /// @param signature Signature over userOpHash.
    /// @param target    Contract the operation will call.
    /// @param selector  Function it will invoke.
    /// @param valueWei  Native value it will move.
    function validateSessionOp(
        address account,
        bytes32 userOpHash,
        bytes calldata signature,
        address target,
        bytes4 selector,
        uint256 valueWei
    ) external view returns (uint256 validationData);

    /// @notice Record spend after a successful operation.
    /// @dev Separate from validation because validation is a view: the EntryPoint may
    ///      simulate it many times, and a simulation must never move the counter.
    ///      Callable only by the account.
    function recordSpend(address signer, uint256 amountWei) external;

    // ------------------------------------------------------------- getters

    function sessionKey(address account, address signer)
        external
        view
        returns (SessionKey memory);

    function remainingSpend(address account, address signer)
        external
        view
        returns (uint256);

    function isPermitted(
        address account,
        address signer,
        address target,
        bytes4 selector
    ) external view returns (bool);
}
