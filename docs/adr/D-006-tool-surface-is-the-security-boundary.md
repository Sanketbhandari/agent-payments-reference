## D-006 — The MCP tool surface is the security boundary, so payment is expressed as purchase

**Date:** 2026-09-05 · **Status:** accepted

### Context

The MCP server decides what an LLM can ask this stack to do. Everything downstream — the
session key, the approval gate, the account — constrains *how much*. Only the tool list
constrains *what*.

That makes the tool surface the first and coarsest control, and the only one that cannot be
argued with at runtime. A capability that is not exposed cannot be reached by a clever prompt,
a compromised context, or a poisoned tool result.

The specific question that forced this record: should there be a `transfer` tool?

### Options

**A. Expose `transfer(to, amount)`.** General, obvious, matches every wallet API.
**B. No `transfer`. Payment is only reachable through `fetch_priced_resource`.**
**C. Expose `transfer` but require approval on every call regardless of amount.**

### Decision

**B.** There is no unconditional send.

The reasoning is about what a human sees when asked to approve. An unconditional transfer
presents an address and a number. The approver has no way to judge it, so approval degrades
into a reflex, and a reflex is not a control.

A payment attached to a resource presents something evaluable: this URL wants this much for
this thing. That is a decision a person can actually make at 2am. So payment is expressed as
buying something, or it is not expressed.

C is the version that feels safe and is not. Approving every transfer trains the approver to
click through, and the tenth prompt gets less attention than the first. Fewer, more meaningful
prompts beat more prompts.

The same reasoning removes `sign_message`. A general signing oracle signs whatever it is
handed, which means the security of everything downstream reduces to the security of the
model's context. That is not a boundary, it is an absence of one.

`install_session_key` and `revoke_session_key` are withheld for a different reason: they are
owner actions. An agent that can grant itself authority has no authority model, and an agent
that can revoke can be made to revoke by anything that reaches its context.

`fetch_priced_resource` takes its own `maxAmount`, and that value can only narrow the client's
ceiling, never widen it. A caller may be more cautious than policy. It may not be less.

`lookup_agent` returns reputation and says in its own description that reputation is a weak
signal and never authorisation. The description is part of the security surface: it is what
the model reads before deciding what to do with the result.

### Cost

An agent that legitimately needs to send funds without a resource attached cannot. Refunds,
settling an off-protocol invoice, paying a person: none of that works here, and each would
need its own tool with its own approval shape rather than one general primitive. That is more
surface to design and more to get wrong, traded for prompts a human can actually judge.

Withholding `revoke_session_key` also means the agent cannot stop itself if it detects it has
been compromised. Revocation is the owner's job and the owner may not be watching. That is a
real gap in the incident path and there is currently nothing filling it.

### Revisit

- If a genuine use case for unattached payment appears, add a narrow tool for that case with
  its own approval prompt. Do not add a general `transfer` and rely on approval to hold it.
- If a monitoring layer ever exists that can revoke on the owner's behalf, the reason for
  withholding revocation weakens, though the tool still should not sit on the agent's surface.
- Tool descriptions are read by the model and should be reviewed like code, since they are
  the only thing standing between a retrieved instruction and a tool call.
