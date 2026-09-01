## D-003 — Session key policy: cumulative lifetime cap, not a rolling window

**Date:** 2026-09-01 · **Status:** accepted for the reference implementation

### Context

A session key exists so an agent can transact without holding unbounded authority. The
interface has to answer three separate questions: who may sign, for how long, and how much.
The first two are straightforward. The third is where the design choices are.

The agent this is built for pays other agents for services over x402. Individual payments are
small and frequent. The failure mode being designed against is not one large theft, it is a
compromised or malfunctioning agent draining an account through many small payments that each
look reasonable.

### Options

**A. Per-transaction cap.** Reject anything above N wei.
Simple, stateless, and useless here. A thousand small payments pass every check.

**B. Rolling window.** N wei per hour or per day.
Matches how humans think about limits, and it is what most consumer products do.

**C. Cumulative lifetime cap.** N wei total until the key expires, counter never resets.
The key burns down and dies.

### Decision

**C**, with a mandatory expiry.

B is the tempting answer and it is worse here. A rolling window needs timestamp arithmetic
inside validation, which the ERC-7562 rules constrain, and it silently renews: a compromised
key with a daily limit keeps working every day until somebody notices. The blast radius is
unbounded over time, which is exactly the property being designed away.

C gives a bounded blast radius by construction. The most an attacker gets from a compromised
key is what remains on it, and the key dies at expiry whether or not anyone is watching.
Refilling is a deliberate act by the account, not a thing that happens by default at midnight.

`validUntil == 0` is rejected on install. A key with no expiry is the exact thing this module
exists to prevent, and making it unrepresentable is better than documenting that you should
not do it.

Empty target and selector arrays mean *no* permissions rather than *all*. Deny-by-default,
because the failure mode of the opposite convention is a key that can call anything because
somebody forgot to populate an array.

### Cost

Operationally worse for a long-running agent. A key that runs out mid-task fails a payment
that would have succeeded under a rolling window, and someone has to notice and refill it.
That is real friction and it is the price of a bounded blast radius. It also pushes work
upward: something has to monitor remaining spend and refill before exhaustion, and that
monitor does not exist yet.

Validation is a `view` and spend is recorded separately, which means an operation that
validates and then reverts during execution does not consume budget. Correct, but it means
the counter reflects settled spend rather than attempted spend, so a key under attack shows
no elevated usage until an attack succeeds.

### Revisit

- If real usage shows keys exhausting mid-task often enough to hurt, add an *optional*
  rolling window as a second, stricter check layered on top of the lifetime cap, never as a
  replacement for it.
- If ERC-7715 converges on a permission grammar that expresses this, adopt it and delete this
  interface. Reimplementing a standard that exists is what D-002 argues against.
- The spend counter is native value only. The moment the agent pays in ERC-20, which x402
  settlement implies, this needs a per-token accounting model and this record should be
  reopened rather than patched.
