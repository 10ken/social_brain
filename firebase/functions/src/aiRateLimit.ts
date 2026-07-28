export const AI_RATE_LIMIT_WINDOW_MS = 60_000;
export const AI_RATE_LIMIT_MAX_REQUESTS = 20;

export type AIRequestRateLimitState = {
  windowStartedAtMs: number;
  requestCount: number;
};

export type AIRequestRateLimitDecision =
  | { allowed: true; nextState: AIRequestRateLimitState }
  | { allowed: false; retryAfterMs: number };

/** Pure rolling-window policy used inside a Firestore transaction. */
export function evaluateAIRequestRateLimit(
  previous: AIRequestRateLimitState | undefined,
  nowMs: number,
): AIRequestRateLimitDecision {
  if (!previous || !Number.isFinite(previous.windowStartedAtMs) ||
    !Number.isInteger(previous.requestCount) || previous.requestCount < 0 ||
    nowMs - previous.windowStartedAtMs >= AI_RATE_LIMIT_WINDOW_MS ||
    nowMs < previous.windowStartedAtMs) {
    return { allowed: true, nextState: { windowStartedAtMs: nowMs, requestCount: 1 } };
  }
  if (previous.requestCount >= AI_RATE_LIMIT_MAX_REQUESTS) {
    return {
      allowed: false,
      retryAfterMs: Math.max(1, previous.windowStartedAtMs + AI_RATE_LIMIT_WINDOW_MS - nowMs),
    };
  }
  return {
    allowed: true,
    nextState: { windowStartedAtMs: previous.windowStartedAtMs, requestCount: previous.requestCount + 1 },
  };
}
