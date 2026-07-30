import { GoogleGenerativeAI } from "@google/generative-ai";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { requireAuthenticatedUser, AuthenticationRequiredError } from "./aiAuth.js";
import {
  ACCOUNT_DELETION_CALLABLE_OPTIONS,
  deleteAccountDataForUser,
  mapAccountDeletionError,
  requireRecentAuthenticatedUser,
  assertEmptyAccountDeletionPayload,
} from "./accountDeletion.js";
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
import { getGeminiModel } from "./geminiConfig.js";

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
        model: getGeminiModel(),
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

/** Permanently removes legacy server data and the authenticated Firebase user. */
export const deleteAccountData = onCall(
  ACCOUNT_DELETION_CALLABLE_OPTIONS,
  async (request) => {
    let userId: string;
    try {
      userId = requireRecentAuthenticatedUser(request.auth).uid;
      assertEmptyAccountDeletionPayload(request.data);
    } catch (error) {
      return mapAccountDeletionError(error);
    }

    try {
      const db = getFirestore();
      await deleteAccountDataForUser(userId, {
        deleteLegacyFirestoreData: (id) => db.recursiveDelete(db.collection("users").doc(id)),
        deleteLegacyStorageData: (id) => getStorage().bucket().deleteFiles({ prefix: `users/${id}/` }),
        deleteRateLimitData: async (id) => {
          await db.collection("internalAiRateLimits").doc(id).delete();
        },
        deleteAuthUser: (id) => getAuth().deleteUser(id),
      });
      return { deleted: true };
    } catch (error) {
      return mapAccountDeletionError(error);
    }
  },
);
