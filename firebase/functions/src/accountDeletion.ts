import { HttpsError } from "firebase-functions/v2/https";
import {
  AuthenticationRequiredError,
  requireAuthenticatedUser,
  type AuthenticatedUser,
} from "./aiAuth.js";

/** A recent sign-in is required before this irreversible operation. */
export const RECENT_AUTH_MAX_AGE_SECONDS = 5 * 60;
const MAX_AUTH_TIME_FUTURE_SKEW_SECONDS = 60;

/** Shared with the callable declaration so App Check remains covered by tests. */
export const ACCOUNT_DELETION_CALLABLE_OPTIONS = {
  enforceAppCheck: true,
  timeoutSeconds: 540,
  memory: "1GiB",
} as const;

export class RecentAuthenticationRequiredError extends Error {
  constructor() {
    super("Sign in again before deleting your account.");
    this.name = "RecentAuthenticationRequiredError";
  }
}

export class AccountDeletionRequestValidationError extends Error {
  constructor() {
    super("Account deletion does not accept a request payload.");
    this.name = "AccountDeletionRequestValidationError";
  }
}

/** Maps account-deletion failures without exposing data paths or server details. */
export function mapAccountDeletionError(error: unknown): never {
  if (error instanceof AuthenticationRequiredError) {
    throw new HttpsError("unauthenticated", error.message);
  }
  if (error instanceof RecentAuthenticationRequiredError) {
    throw new HttpsError("failed-precondition", error.message);
  }
  if (error instanceof AccountDeletionRequestValidationError) {
    throw new HttpsError("invalid-argument", error.message);
  }
  if (error instanceof HttpsError) throw error;
  // Do not include account IDs, data paths, error messages, or request data.
  throw new HttpsError("unavailable", "Account deletion is temporarily unavailable.");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function readAuthTime(auth: unknown): number | undefined {
  if (!isRecord(auth) || !isRecord(auth.token)) return undefined;
  const authTime = auth.token.auth_time;
  return typeof authTime === "number" && Number.isSafeInteger(authTime) ? authTime : undefined;
}

/**
 * Uses the verified callable auth token's auth_time claim, never caller data,
 * to require a sufficiently recent authentication event for account deletion.
 */
export function requireRecentAuthenticatedUser(
  auth: unknown,
  nowMs = Date.now(),
): AuthenticatedUser {
  const user = requireAuthenticatedUser(auth, "Sign in before deleting your account.");
  const authTime = readAuthTime(auth);
  const nowSeconds = Math.floor(nowMs / 1_000);
  const ageSeconds = authTime === undefined ? Number.POSITIVE_INFINITY : nowSeconds - authTime;

  if (!Number.isFinite(nowMs) || authTime === undefined ||
    authTime > nowSeconds + MAX_AUTH_TIME_FUTURE_SKEW_SECONDS ||
    ageSeconds > RECENT_AUTH_MAX_AGE_SECONDS) {
    throw new RecentAuthenticationRequiredError();
  }
  return user;
}

/** The callable has no input; rejecting data avoids silently retaining new API surface. */
export function assertEmptyAccountDeletionPayload(value: unknown): void {
  if (value === undefined || value === null || (isRecord(value) && Object.keys(value).length === 0)) {
    return;
  }
  throw new AccountDeletionRequestValidationError();
}

export type AccountDataDeletionDependencies = {
  deleteLegacyFirestoreData: (userId: string) => Promise<void>;
  deleteLegacyStorageData: (userId: string) => Promise<void>;
  deleteRateLimitData: (userId: string) => Promise<void>;
  deleteAuthUser: (userId: string) => Promise<void>;
};

/**
 * Delete server-side remnants first and remove Firebase Auth only after they
 * succeed. This keeps a retry path available when cleanup is temporarily down.
 */
export async function deleteAccountDataForUser(
  userId: string,
  dependencies: AccountDataDeletionDependencies,
): Promise<void> {
  await dependencies.deleteLegacyFirestoreData(userId);
  await dependencies.deleteLegacyStorageData(userId);
  await dependencies.deleteRateLimitData(userId);
  await dependencies.deleteAuthUser(userId);
}
