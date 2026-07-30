export type AuthenticatedUser = { uid: string };

export class AuthenticationRequiredError extends Error {
  constructor(message = "Sign in before using AI features.") {
    super(message);
    this.name = "AuthenticationRequiredError";
  }
}

/** Keeps Firebase callable authentication validation testable and content-free. */
export function requireAuthenticatedUser(
  auth: unknown,
  message?: string,
): AuthenticatedUser {
  if (!auth || typeof auth !== "object" || !("uid" in auth) ||
    typeof auth.uid !== "string" || auth.uid.trim().length === 0) {
    throw new AuthenticationRequiredError(message);
  }
  return { uid: auth.uid };
}
