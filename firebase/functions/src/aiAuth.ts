export type AuthenticatedUser = { uid: string };

export class AuthenticationRequiredError extends Error {
  constructor() {
    super("Sign in before using AI features.");
    this.name = "AuthenticationRequiredError";
  }
}

/** Keeps Firebase callable authentication validation testable and content-free. */
export function requireAuthenticatedUser(auth: unknown): AuthenticatedUser {
  if (!auth || typeof auth !== "object" || !("uid" in auth) ||
    typeof auth.uid !== "string" || auth.uid.trim().length === 0) {
    throw new AuthenticationRequiredError();
  }
  return { uid: auth.uid };
}
