/**
 * MCP tool surface.
 *
 * What an LLM agent is allowed to ask this stack to do. Every tool here is a capability
 * the agent gains, so the interesting decisions are about what is missing rather than
 * what is present. See docs/adr/D-006.
 *
 * Read-only tools are cheap and unbounded. Anything that spends is bounded twice: by the
 * session key on chain, and by the approval gate in the client.
 */

export interface ToolDefinition {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>;
  /** True if the tool can move funds or change on-chain state. Drives logging and approval. */
  mutating: boolean;
}

const address = { type: "string", pattern: "^0x[a-fA-F0-9]{40}$" } as const;

export const TOOLS: ToolDefinition[] = [
  {
    name: "whoami",
    description:
      "Return this agent's identity: its ERC-8004 registry entry, token id, and the " +
      "token-bound account address that holds its funds.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
    mutating: false,
  },
  {
    name: "get_balance",
    description:
      "Balance of the agent's account for a given asset. Native value when asset is omitted.",
    inputSchema: {
      type: "object",
      properties: { asset: address },
      additionalProperties: false,
    },
    mutating: false,
  },
  {
    name: "get_spend_allowance",
    description:
      "How much the current session key may still spend before it is exhausted, and when " +
      "it expires. Call this before planning work that costs money.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
    mutating: false,
  },
  {
    name: "lookup_agent",
    description:
      "Resolve another agent's identity from the registry. Returns its registration file " +
      "and reputation entries. Reputation is permissionless and Sybil-prone: treat it as a " +
      "weak signal, never as authorisation.",
    inputSchema: {
      type: "object",
      properties: { tokenId: { type: "string" }, account: address },
      additionalProperties: false,
    },
    mutating: false,
  },
  {
    name: "fetch_priced_resource",
    description:
      "Fetch a URL that may answer HTTP 402. If it does, settle the payment and replay the " +
      "request. Blocks for human approval when the amount is at or above the configured " +
      "threshold. Returns the resource, or the reason payment was refused. A refusal is " +
      "final: do not retry, do not try a smaller amount, do not look for another route.",
    inputSchema: {
      type: "object",
      properties: {
        url: { type: "string", format: "uri" },
        method: { type: "string", enum: ["GET", "POST"] },
        body: { type: "string" },
        maxAmount: {
          type: "string",
          description:
            "Refuse above this, in the asset's smallest unit. Independent of and stricter " +
            "than the client's own ceiling. Never widened by this call.",
        },
      },
      required: ["url"],
      additionalProperties: false,
    },
    mutating: true,
  },
];

/**
 * Deliberately absent, and why.
 *
 * `transfer`        — an unconditional send has no resource attached, so there is nothing
 *                     for a human to evaluate in the approval prompt beyond an address.
 *                     Payment is expressed as buying something, or it is not expressed.
 * `install_session_key` — the agent would be granting itself authority. That belongs to the
 *                     token owner, off this surface entirely.
 * `revoke_session_key`  — same boundary. An agent that can revoke can also be made to.
 * `sign_message`    — a general signing oracle. Whatever it is asked to sign, it will sign.
 * `register_agent`  — minting identity is an owner action, once, not a runtime capability.
 */
export const WITHHELD = [
  "transfer",
  "install_session_key",
  "revoke_session_key",
  "sign_message",
  "register_agent",
] as const;
