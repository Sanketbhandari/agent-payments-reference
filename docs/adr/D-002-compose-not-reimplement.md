## D-002 — Compose the existing standards rather than reimplement them

**Date:** 2026-08-29 · **Status:** accepted

### Context

The goal is a worked example of an agent that holds its own identity and wallet and can pay
for things under bounded authority. Every piece of that already exists as a standard, and most
have reference implementations: ERC-8004 registries went to mainnet in January 2026, ERC-6551
has a singleton registry, ERC-4337 has EntryPoint and a mature bundler ecosystem, and x402 has
working middleware.

The tempting version of this project is to write my own identity registry. It would be more
code, it would look more impressive at a glance, and it would be worth nothing, because the
interesting problem is not any single layer.

### Options

**A. Reimplement the registries from scratch.**
More visible code. Demonstrates Solidity ability directly.

**B. Compose the existing reference implementations, and write only the connective layer.**
Less code. The work is in the integration, the session-key policy, and the approval gate.

**C. Fork the reference contracts and modify them.**
A middle path. Keeps control, avoids starting from nothing.

### Decision

**B.** Import the reference contracts, write the connective layer.

The gap in this ecosystem is not another identity registry. It is that nobody has published a
clean example of the four layers working together, including the places where they do not fit.
Reimplementing 8004 would produce a worse version of something that already exists and would
skip the part that is actually unsolved.

Option C loses the main benefit of B — if the upstream contracts change, a fork silently drifts,
and the whole point is to demonstrate composition against the real thing.

### Cost

Less Solidity on display. Anyone skimming for lines of contract code will find a thin repo,
and this project will be read as integration work rather than protocol work. That is a real
cost and I am accepting it, because the alternative is a repo that looks bigger and teaches
nothing.

There is also a dependency risk: ERC-8004 is a Draft and ERC-6551 is in Review. Both can change
under me. That is a reason to pin versions and say so, not a reason to fork.

### Revisit

- If a layer's reference implementation turns out to be unusable for a reason that matters
  (licence, quality, or an interface that cannot express the session-key case), fork that one
  layer and record why.
- If ERC-8004 changes materially before this ships, re-read the diff before assuming the
  integration still holds.
- If the connective layer stays trivial once written, the project is not worth publishing and
  should be folded into the architecture notes instead.
