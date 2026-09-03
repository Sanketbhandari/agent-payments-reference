## D-005 — The human approval gate sits in the client, above the session key, and blocks

**Date:** 2026-09-03 · **Status:** accepted

### Context

The agent has two things limiting what it can spend: a session key with a cumulative cap
enforced on chain (D-003), and a human who wants to be asked before large payments leave.

Those are not the same control and they fail differently. The session key is trustless and
absolute: it cannot be talked out of its limit, and it also cannot be reasoned with when a
legitimate payment sits one wei above the cap. The human gate is discretionary: it exists for
the payments that are within policy but still want a second opinion.

The question is where the second one lives, and what happens while it waits.

### Options

**A. On chain, in the validator.** A payment above the threshold requires a co-signature.
**B. In the facilitator.** The settlement service holds the payment pending approval.
**C. In the client, before signing.** The agent asks, and does not sign until answered.

### Decision

**C.** The gate is a client-side interface (`SpendApproval`), called before signing, and it
blocks.

A puts a human in a validation path that the EntryPoint simulates repeatedly and expects to
complete in milliseconds. It would also make approval a transaction, which costs gas to say
no. Wrong place.

B moves custody of the decision to a third party. The facilitator would hold a signed
authorisation while waiting, which means for the duration of the wait somebody else holds a
signature that could settle. That is worse than the problem it solves.

C keeps the signature unmade until a person answers. Nothing exists to be replayed, leaked or
front-run, because nothing has been signed. The cost is that the agent stops, and stopping is
the correct behaviour for something about to move money it was told to ask about.

**Returning false abandons the payment.** It does not queue it, retry it later, or reduce the
amount and try again. An agent that responds to "no" by finding a smaller "yes" has turned a
refusal into a negotiation, and the human said no once.

`maxPerRequest` is a hard ceiling independent of approval. Even an approved payment above it
is refused before signing, so a mistaken or coerced approval has a bound.

`allowedRecipients` empty means none rather than all, same convention as the session key
targets. `serverMessage` is marked untrusted in the type because it arrives from whoever is
being paid, and it is displayed to the human making the decision. That is a prompt-injection
surface and naming it in the type is cheaper than remembering.

### Cost

The agent blocks, potentially for hours, on a human who may be asleep. Any workflow with a
payment in it inherits that latency, and there is currently no timeout, no escalation path and
no queue. A long-running agent that hits the threshold overnight simply stops.

Verification and settlement being separate calls means a payment can verify and then fail to
settle, and this interface does not say who retries or whether the resource is delivered
meanwhile. That is a real gap, not a simplification.

### Revisit

- If blocking proves unworkable, the answer is a **pre-authorisation window** granted ahead of
  time, not an asynchronous approval that leaves a signature waiting somewhere.
- Once payments are ERC-20 rather than native value, the session key accounting in D-003 has
  to become per-token, and the threshold here needs to be denominated per asset rather than
  compared as a raw integer.
- If a facilitator ever settles without a fresh signature per payment, revisit B's rejection.
  The objection was custody of a live signature, not the architecture.
