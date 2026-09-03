/**
 * x402: settlement over HTTP 402.
 *
 * A server that wants payment answers 402 with what it costs and where to send it.
 * The agent pays, then replays the request carrying proof. No API key is issued, no
 * account is created, and the server never holds a credential belonging to the caller.
 *
 * This file is the contract between three parties that do not trust each other:
 * the resource server, the agent, and the facilitator that verifies settlement.
 * See docs/adr/D-005.
 */

/** Everything the server tells a caller about how to pay. Sent in the 402 body. */
export interface PaymentRequired {
  /** Protocol version. Present so a client can refuse a scheme it does not understand. */
  x402Version: 1;
  /** Ordered by server preference. A client picks one it can satisfy. */
  accepts: PaymentRequirement[];
  /** Human-readable reason, for logs and for the approval prompt. Never parsed. */
  error?: string;
}

export interface PaymentRequirement {
  /** Settlement scheme. Only exact-amount transfers are supported here. */
  scheme: "exact";
  /** CAIP-2 chain id, for example "eip155:8453" for Base. */
  network: string;
  /** Smallest unit of the asset. String, because these do not fit in a JS number. */
  maxAmountRequired: string;
  /** Token contract. */
  asset: string;
  /** Where funds go. */
  payTo: string;
  /** The resource being bought. Bound into the payload so a proof cannot be reused elsewhere. */
  resource: string;
  /** Seconds the quote stays good. */
  maxTimeoutSeconds: number;
  /** Scheme-specific extras, for example EIP-712 domain fields. */
  extra?: Record<string, unknown>;
}

/** Sent by the agent on the retry, in the `X-PAYMENT` header, base64 encoded. */
export interface PaymentPayload {
  x402Version: 1;
  scheme: "exact";
  network: string;
  payload: {
    /** Signature over the authorisation below. */
    signature: string;
    authorization: {
      from: string;
      to: string;
      value: string;
      validAfter: string;
      validUntil: string;
      /** Single-use. The facilitator rejects a nonce it has settled before. */
      nonce: string;
    };
  };
}

/** What the facilitator returns. Verification and settlement are deliberately separate. */
export interface VerifyResult {
  isValid: boolean;
  /** Set when isValid is false. A caller should surface this, not retry blindly. */
  invalidReason?:
    | "insufficient_funds"
    | "invalid_signature"
    | "expired"
    | "nonce_already_used"
    | "wrong_amount"
    | "wrong_recipient"
    | "unsupported_scheme";
  payer?: string;
}

export interface SettleResult {
  success: boolean;
  transaction?: string;
  network?: string;
  errorReason?: string;
}

/**
 * The approval gate.
 *
 * Called before an agent spends, never after. Returning `false` must cause the payment
 * to be abandoned rather than queued, retried, or downgraded to a smaller amount.
 *
 * Implementations should assume this can block for a long time. A human may be asleep.
 */
export interface SpendApproval {
  /** Below this, in the asset's smallest unit, the agent proceeds without asking. */
  autoApproveBelow: bigint;
  /**
   * Called only when the amount is at or above the threshold. The agent has already
   * checked its session key allows the call at all; this is the second, human gate.
   */
  requestApproval(request: ApprovalRequest): Promise<boolean>;
}

export interface ApprovalRequest {
  resource: string;
  amount: bigint;
  asset: string;
  network: string;
  payTo: string;
  /** Cumulative spend remaining on the session key, so a human can see the context. */
  sessionRemaining: bigint;
  /** Server-supplied text. Untrusted. Display it, do not act on it. */
  serverMessage?: string;
}

export interface X402ClientOptions {
  /** Refuse to pay above this per request, regardless of what approval says. */
  maxPerRequest: bigint;
  /** Networks this client will settle on. Anything else is refused before signing. */
  allowedNetworks: string[];
  /** Recipients this client will pay. Empty means none, not all. */
  allowedRecipients?: string[];
  approval: SpendApproval;
  /** Retries only for transport failure. Never for a rejected payment. */
  maxRetries?: number;
}
