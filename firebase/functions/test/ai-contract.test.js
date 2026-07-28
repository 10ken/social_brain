const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const {
  AIContractValidationError,
  AIResponseSizeError,
  MAX_AI_RESPONSE_BYTES,
  ensureAIResponseWithinLimit,
  isAIExtractionResult,
  parseAIExtractionOutput,
} = require("../lib/aiContract.js");
const { AuthenticationRequiredError, requireAuthenticatedUser } = require("../lib/aiAuth.js");
const { AIRequestValidationError, parseAIRequest } = require("../lib/aiRequest.js");
const {
  AI_RATE_LIMIT_MAX_REQUESTS,
  AI_RATE_LIMIT_WINDOW_MS,
  evaluateAIRequestRateLimit,
} = require("../lib/aiRateLimit.js");

const fixturePath = (...segments) => path.join(
  __dirname,
  "../../../shared/contracts/v1/fixtures",
  ...segments,
);

test("accepts the shared camelCase extraction fixture", () => {
  const text = fs.readFileSync(fixturePath("ai-extraction.valid.json"), "utf8");
  const result = parseAIExtractionOutput(text);

  assert.equal(isAIExtractionResult(result), true);
  assert.equal(result.events[0].resolvedDate, "2026-06-13");
  assert.equal(result.relationships[0].personA, "Alex");
});

test("rejects deprecated snake_case and malformed JSON model output without echoing it", () => {
  const legacy = fs.readFileSync(fixturePath("ai-extraction.invalid.json"), "utf8");
  const secretOutput = `${legacy} unique-sensitive-model-output`;

  assert.throws(
    () => parseAIExtractionOutput(secretOutput),
    (error) => error instanceof AIContractValidationError && !error.message.includes("unique-sensitive-model-output"),
  );
  assert.throws(() => parseAIExtractionOutput("not JSON"), AIContractValidationError);
});

test("bounds both structured and plain-text model output before it reaches a client", () => {
  assert.doesNotThrow(() => ensureAIResponseWithinLimit("short answer"));
  assert.throws(
    () => ensureAIResponseWithinLimit("x".repeat(MAX_AI_RESPONSE_BYTES + 1)),
    AIResponseSizeError,
  );
});

test("preserves validated inline images in the callable request", () => {
  const dataBase64 = Buffer.from("tiny image").toString("base64");
  const request = parseAIRequest({
    prompt: "Extract this screenshot",
    responseMimeType: "application/json",
    image: { mimeType: "image/jpeg", dataBase64 },
  });

  assert.deepEqual(request.image, { mimeType: "image/jpeg", dataBase64 });
  assert.equal(request.responseMimeType, "application/json");
});

test("rejects invalid, oversized-shape, and unsupported callable requests", () => {
  assert.throws(
    () => parseAIRequest({ prompt: "x", responseMimeType: "text/html" }),
    AIRequestValidationError,
  );
  assert.throws(
    () => parseAIRequest({
      prompt: "x",
      image: { mimeType: "image/jpeg", dataBase64: "not valid base64!" },
    }),
    AIRequestValidationError,
  );
  assert.throws(
    () => parseAIRequest({ prompt: "x", internalDebug: "never accepted" }),
    AIRequestValidationError,
  );
});

test("requires an authenticated Firebase user before AI work", () => {
  assert.throws(() => requireAuthenticatedUser(null), AuthenticationRequiredError);
  assert.throws(() => requireAuthenticatedUser({ uid: "" }), AuthenticationRequiredError);
  assert.deepEqual(requireAuthenticatedUser({ uid: "user-123" }), { uid: "user-123" });
});

test("enforces a stable per-user rolling request window", () => {
  const start = 1_000_000;
  let state;
  for (let request = 1; request <= AI_RATE_LIMIT_MAX_REQUESTS; request += 1) {
    const decision = evaluateAIRequestRateLimit(state, start + request);
    assert.equal(decision.allowed, true);
    state = decision.nextState;
  }

  const rejected = evaluateAIRequestRateLimit(state, start + 10);
  assert.equal(rejected.allowed, false);
  assert.ok(rejected.retryAfterMs > 0);

  const nextWindow = evaluateAIRequestRateLimit(state, start + AI_RATE_LIMIT_WINDOW_MS + 1);
  assert.equal(nextWindow.allowed, true);
  assert.equal(nextWindow.nextState.requestCount, 1);
});
