import { GoogleGenerativeAI } from "@google/generative-ai";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { requireAuthenticatedUser, AuthenticationRequiredError } from "./aiAuth.js";
import {
  AIContractValidationError,
  AIResponseSizeError,
  ensureAIResponseWithinLimit,
  parseAIExtractionOutput,
} from "./aiContract.js";
import { AIRequestValidationError, parseAIRequest } from "./aiRequest.js";
import {
  AI_RATE_LIMIT_WINDOW_MS,
  evaluateAIRequestRateLimit,
  type AIRequestRateLimitState,
} from "./aiRateLimit.js";

initializeApp();

const geminiApiKey = defineSecret("GEMINI_API_KEY");

function mapRequestError(error: unknown): never {
  if (error instanceof AuthenticationRequiredError) {
    throw new HttpsError("unauthenticated", error.message);
  }
  if (error instanceof AIRequestValidationError) {
    throw new HttpsError("invalid-argument", error.message);
  }
  if (error instanceof AIContractValidationError) {
    throw new HttpsError("failed-precondition", "AI returned an invalid extraction result. Try again.");
  }
  if (error instanceof AIResponseSizeError) {
    throw new HttpsError("resource-exhausted", "AI response exceeded a safe size. Try again.");
  }
  if (error instanceof HttpsError) throw error;
  throw new HttpsError("unavailable", "AI processing is temporarily unavailable.");
}

function readRateLimitState(value: unknown): AIRequestRateLimitState | undefined {
  if (!value || typeof value !== "object") return undefined;
  const data = value as Record<string, unknown>;
  const windowStartedAtMs = data.windowStartedAtMs;
  const requestCount = data.requestCount;
  if (typeof windowStartedAtMs !== "number" || typeof requestCount !== "number") return undefined;
  return { windowStartedAtMs, requestCount };
}

/** Uses Firestore transactions so quota is enforced across concurrent instances. */
async function takeAIRequestRateLimitSlot(userId: string): Promise<void> {
  const db = getFirestore();
  const limitRef = db.collection("internalAiRateLimits").doc(userId);
  const decision = await db.runTransaction(async (transaction) => {
    const current = readRateLimitState((await transaction.get(limitRef)).data());
    const next = evaluateAIRequestRateLimit(current, Date.now());
    if (next.allowed) {
      transaction.set(limitRef, {
        windowStartedAtMs: next.nextState.windowStartedAtMs,
        requestCount: next.nextState.requestCount,
        expiresAtMs: next.nextState.windowStartedAtMs + AI_RATE_LIMIT_WINDOW_MS,
      });
    }
    return next;
  });

  if (!decision.allowed) {
    throw new HttpsError("resource-exhausted", "Too many AI requests. Please try again shortly.");
  }
}

/** User-initiated Gemini proxy. Request content and model output are never logged. */
export const generateAIContent = onCall(
  { secrets: [geminiApiKey], enforceAppCheck: true, timeoutSeconds: 60, memory: "512MiB" },
  async (request) => {
    let userId: string;
    let input: ReturnType<typeof parseAIRequest>;
    try {
      userId = requireAuthenticatedUser(request.auth).uid;
      input = parseAIRequest(request.data);
    } catch (error) {
      return mapRequestError(error);
    }

    try {
      await takeAIRequestRateLimitSlot(userId);
      const client = new GoogleGenerativeAI(geminiApiKey.value());
      const model = client.getGenerativeModel({
        model: process.env.GEMINI_MODEL ?? "gemini-2.0-flash",
        systemInstruction: input.systemInstruction,
        generationConfig: { responseMimeType: input.responseMimeType },
      });
      const content = input.image
        ? [{ text: input.prompt }, { inlineData: { mimeType: input.image.mimeType, data: input.image.dataBase64 } }]
        : input.prompt;
      const result = await model.generateContent(content);
      const text = result.response.text();
      ensureAIResponseWithinLimit(text);
      if (input.responseMimeType === "application/json") {
        parseAIExtractionOutput(text);
      }
      return { text };
    } catch (error) {
      return mapRequestError(error);
    }
  },
);

/** Explicit clean-slate action for an account with a forgotten sync passphrase. */
export const resetEncryptedContent = onCall(
  { enforceAppCheck: true, timeoutSeconds: 540, memory: "1GiB" },
  async (request) => {
    let userId: string;
    try {
      userId = requireAuthenticatedUser(request.auth).uid;
    } catch (error) {
      return mapRequestError(error);
    }

    try {
      const db = getFirestore();
      await db.recursiveDelete(db.collection("users").doc(userId));
      await getStorage().bucket().deleteFiles({ prefix: `users/${userId}/` });
      return { reset: true };
    } catch {
      // Do not include account, storage, or content details in an API error.
      throw new HttpsError("unavailable", "Content reset is temporarily unavailable.");
    }
  },
);
