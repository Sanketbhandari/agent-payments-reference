## D-004 — An account that exists but cannot validate is a real state, and it fails closed

**Date:** 2026-09-02 · **Status:** accepted · **Follows:** D-001

### Context

D-001 left a question open: if validation lives in a module rather than in the account, what
installs the module, and when?

The ERC-6551 registry computes an account address deterministically from the chain, the token
contract and the token id. The address exists as soon as the NFT does. Deployment is a
separate act, and installing a validator is a third. So there is a window, potentially a long
one, where an agent has an identity and an address that can receive funds, and no ability to
authorise spending them.

That window is not an edge case to be engineered away. It is the normal path: the identity is
minted first, the account is funded, and only then does someone decide what the agent is
allowed to do.

### Options

**A. Fall back to owner-only when no validator is installed.**
The account behaves like a plain 6551 account until a module shows up. Nothing breaks.

**B. Install a default validator at deployment.**
The account is never in the incapable state. Deployment and capability become one act.

**C. Revert explicitly when a UserOperation arrives with no validator.**
The state is representable, named, and fails closed.

### Decision

**C**, with `NoValidatorInstalled` as a named error.

A is the quiet option and that is the problem with it. A silent fallback to owner-only means
a bundler-routed operation that should have been checked against a spend limit instead gets
checked against ownership, and succeeds. The failure is invisible: everything works, and the
authority model is not the one anyone designed. A misconfigured account should be obviously
broken, not quietly permissive.

B removes the window by removing the choice, and the choice is the point. What an agent may do
is a policy decision made by whoever controls the identity, not a default baked in at
deployment. It also means every account carries a validator it might never use.

C makes the state explicit. An account can hold funds and be unable to move them through the
4337 path, and that reads as "not configured yet" rather than as a bug. The token owner can
still act directly, which is the recovery path.

`uninstallValidator` refusing to remove the last one follows from the same reasoning. The
incapable state is acceptable on the way in, before anyone has expressed intent. Arriving
there by removing the last validator from a funded, working account is different, and should
take a deliberate act rather than one transaction that looks like cleanup.

### Cost

An account can be funded and unusable through the bundler, and nothing in the contract warns
you before it happens. The first symptom is a reverted UserOperation, which is a poor place to
learn about a configuration problem. This wants tooling that neither exists nor is planned:
something that checks whether a funded account has a validator, and says so.

The asymmetry between "may start with no validator" and "may not end with none" is a rule
someone will hit and find surprising. Documented here rather than defended in review.

### Revisit

- If the deploy path in practice always installs a validator in the same transaction, the
  window closes on its own and option B becomes honest rather than presumptuous. Reopen then.
- If ERC-7579 module-installation conventions settle somewhere that contradicts this, follow
  the standard.
- The recovery story is currently "the token owner acts directly". If the token owner is
  itself an agent account, that is circular and this record does not cover it.
