const assert = require("node:assert/strict");
const test = require("node:test");

const { AuthenticationRequiredError } = require("../lib/aiAuth.js");
const {
  ACCOUNT_DELETION_CALLABLE_OPTIONS,
  AccountDeletionRequestValidationError,
  deleteAccountDataForUser,
  mapAccountDeletionError,
  RecentAuthenticationRequiredError,
  RECENT_AUTH_MAX_AGE_SECONDS,
  requireRecentAuthenticatedUser,
  assertEmptyAccountDeletionPayload,
} = require("../lib/accountDeletion.js");
const { DEFAULT_GEMINI_MODEL, resolveGeminiModel } = require("../lib/geminiConfig.js");

test("uses gemini-3.6-flash by default while allowing an explicit model override", () => {
  assert.equal(DEFAULT_GEMINI_MODEL, "gemini-3.6-flash");
  assert.equal(resolveGeminiModel(undefined), DEFAULT_GEMINI_MODEL);
  assert.equal(resolveGeminiModel("   "), DEFAULT_GEMINI_MODEL);
  assert.equal(resolveGeminiModel("gemini-custom-model"), "gemini-custom-model");
});

test("requires App Check configuration, authenticated user, and recent verified authentication", () => {
  const nowMs = 1_800_000_000_000;
  const nowSeconds = Math.floor(nowMs / 1_000);

  assert.equal(ACCOUNT_DELETION_CALLABLE_OPTIONS.enforceAppCheck, true);
  assert.deepEqual(
    requireRecentAuthenticatedUser({
      uid: "user-123",
      token: { auth_time: nowSeconds - RECENT_AUTH_MAX_AGE_SECONDS },
    }, nowMs),
    { uid: "user-123" },
  );
  assert.throws(
    () => requireRecentAuthenticatedUser(null, nowMs),
    AuthenticationRequiredError,
  );
  assert.throws(
    () => requireRecentAuthenticatedUser({ uid: "user-123", token: {} }, nowMs),
    RecentAuthenticationRequiredError,
  );
  assert.throws(
    () => requireRecentAuthenticatedUser({
      uid: "user-123",
      token: { auth_time: nowSeconds - RECENT_AUTH_MAX_AGE_SECONDS - 1 },
    }, nowMs),
    RecentAuthenticationRequiredError,
  );
  assert.throws(
    () => requireRecentAuthenticatedUser({
      uid: "user-123",
      token: { auth_time: nowSeconds + 61 },
    }, nowMs),
    RecentAuthenticationRequiredError,
  );
});

test("accepts no account-deletion payload and never echoes rejected data", () => {
  assert.doesNotThrow(() => assertEmptyAccountDeletionPayload(undefined));
  assert.doesNotThrow(() => assertEmptyAccountDeletionPayload(null));
  assert.doesNotThrow(() => assertEmptyAccountDeletionPayload({}));

  const sensitivePayload = { confirmation: "unique-sensitive-delete-payload" };
  assert.throws(
    () => assertEmptyAccountDeletionPayload(sensitivePayload),
    (error) => error instanceof AccountDeletionRequestValidationError &&
      !error.message.includes("unique-sensitive-delete-payload"),
  );
});

test("maps account-deletion failures to safe callable error codes", () => {
  const assertCallableError = (input, expectedCode, sensitiveText) => {
    assert.throws(
      () => mapAccountDeletionError(input),
      (error) => error.code === expectedCode &&
        (sensitiveText === undefined || !error.message.includes(sensitiveText)),
    );
  };

  assertCallableError(new AuthenticationRequiredError(), "unauthenticated");
  assertCallableError(new RecentAuthenticationRequiredError(), "failed-precondition");
  assertCallableError(new AccountDeletionRequestValidationError(), "invalid-argument");
  assertCallableError(
    new Error("unique-sensitive-account-deletion-server-error"),
    "unavailable",
    "unique-sensitive-account-deletion-server-error",
  );
});

test("removes legacy data and rate-limit metadata before deleting Firebase Auth", async () => {
  const calls = [];
  const step = (name) => async (userId) => {
    calls.push(`${name}:${userId}`);
  };

  await deleteAccountDataForUser("user-123", {
    deleteLegacyFirestoreData: step("firestore"),
    deleteLegacyStorageData: step("storage"),
    deleteRateLimitData: step("rate-limit"),
    deleteAuthUser: step("auth"),
  });

  assert.deepEqual(calls, [
    "firestore:user-123",
    "storage:user-123",
    "rate-limit:user-123",
    "auth:user-123",
  ]);
});

test("does not delete Firebase Auth when server-data cleanup fails", async () => {
  let authDeleteCalled = false;

  await assert.rejects(
    () => deleteAccountDataForUser("user-123", {
      deleteLegacyFirestoreData: async () => {},
      deleteLegacyStorageData: async () => {
        throw new Error("storage temporarily unavailable");
      },
      deleteRateLimitData: async () => {},
      deleteAuthUser: async () => {
        authDeleteCalled = true;
      },
    }),
    /storage temporarily unavailable/,
  );

  assert.equal(authDeleteCalled, false);
});
