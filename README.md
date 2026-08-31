# agent-payments-reference

A worked example of an AI agent that has its own identity, its own wallet, and bounded
authority to spend from it.

Built from public standards. Nothing here is novel on its own — ERC-8004, ERC-6551, ERC-4337
and x402 all exist and all have reference implementations. What is missing is a clean example
of how they fit together, and what breaks when you try.

> **Status: in progress.** Architecture and decisions are written. Contracts are not.
> Deployed addresses go here when there are any.

## The problem

An agent that can pay for things needs signing authority. Hand it an ordinary private key and
you have given unbounded, permanent power to something whose behaviour you cannot fully
predict. That is the whole problem, and most agent demos skip it by holding the key
themselves.

Four questions have to be answered separately, and answering one does not answer the others:

| Question | Answered by |
|---|---|
| Who is this agent? | ERC-8004 identity registry |
| What owns its wallet? | ERC-6551 token-bound account |
| How much may it spend, and for how long? | Session-key module |
| How does it actually pay? | x402 over HTTP 402 |

## Architecture

```mermaid
flowchart TB
    subgraph runtime["Runtime"]
        MCP["MCP server<br/><i>register · balance · pay</i>"]
    end

    subgraph payment["Payment"]
        X402["x402 middleware<br/><i>402 → pay → replay</i>"]
    end

    subgraph authority["Authority"]
        SK["Session key module<br/><i>scoped · time-boxed · spend-limited</i>"]
        GATE{{"Human approval<br/>above threshold"}}
    end

    subgraph account["Account"]
        TBA["ERC-6551 token-bound account"]
    end

    subgraph identity["Identity"]
        REG["ERC-8004 identity registry<br/><i>ERC-721</i>"]
    end

    MCP --> X402
    X402 --> SK
    SK --> GATE
    SK --> TBA
    TBA --> REG
    REG -.->|owns| TBA
```

![Agent wallet stack](docs/diagrams/agent-wallet-stack.png)

The agent's identity NFT owns the account. Transfer the token and the wallet goes with it, in
one transaction, with no key handover. Authority is a module on top, so it can be narrowed or
revoked without moving funds.

## Why both 4337 and 7702

A recurring question: if EIP-7702 lets an existing EOA delegate to contract code, is ERC-4337
still needed? Yes. They answer different halves.

![7702 and 4337](docs/diagrams/7702-vs-4337.png)

A 7702-delegated EOA still needs a bundler to relay its operations and a paymaster to sponsor
its gas. 7702 changed which accounts can be upgraded. It did not remove the infrastructure
underneath them.

## What this is not

- **Not a reimplementation of ERC-8004.** The reference contracts already exist at
  [erc-8004/erc-8004-contracts](https://github.com/erc-8004/erc-8004-contracts). This composes
  with them.
- **Not audited.** Not deployed to anything that holds real value beyond a demo.
- **Not a framework.** One worked path, written to be read.

## The unresolved part

A 6551 account is not a 4337 account. The 6551 spec never mentions 4337, so a bundler will not
touch the account until something implements `validateUserOp`. Three options, and the choice
is written up in [D-002](docs/adr/D-002-compose-not-reimplement.md) and
[D-001](https://github.com/Sanketbhandari/architecture-notes/blob/main/decisions/D-001-validateuserop-placement.md).

Current position: validation belongs in a module rather than in the account. That is reasoning,
not evidence, until the code exists.

## Decisions

Every non-obvious choice is recorded in `docs/adr/` with the alternatives that were rejected
and what would make it worth revisiting. Start with D-002.

## Running it locally

Nothing to run yet. This section gets filled in when the contracts land.

## License

MIT
