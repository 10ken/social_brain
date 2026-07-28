import { GoogleGenerativeAI } from "@google/generative-ai";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";

initializeApp();

const geminiApiKey = defineSecret("GEMINI_API_KEY");
const maximumPromptBytes = 250_000;

type AIRequest = {
  prompt: string;
  systemInstruction?: string;
  responseMimeType?: "application/json" | "text/plain";
  image?: { mimeType: string; dataBase64: string };
};

function requireAuthenticatedRequest(auth: unknown): asserts auth is { uid: string } {
  if (!auth || typeof auth !== "object" || !("uid" in auth)) {
    throw new HttpsError("unauthenticated", "Sign in before using AI features.");
  }
}

function parseAIRequest(value: unknown): AIRequest {
  if (!value || typeof value !== "object") {
    throw new HttpsError("invalid-argument", "A request payload is required.");
  }
  const request = value as Partial<AIRequest>;
  if (typeof request.prompt !== "string" || request.prompt.trim().length === 0) {
    throw new HttpsError("invalid-argument", "A non-empty prompt is required.");
  }
  if (Buffer.byteLength(request.prompt, "utf8") > maximumPromptBytes) {
    throw new HttpsError("invalid-argument", "Prompt exceeds the allowed size.");
  }
  if (request.systemInstruction !== undefined && typeof request.systemInstruction !== "string") {
    throw new HttpsError("invalid-argument", "systemInstruction must be text.");
  }
  if (request.image !== undefined) {
    if (typeof request.image !== "object" || typeof request.image.mimeType !== "string" ||
      typeof request.image.dataBase64 !== "string" || !request.image.mimeType.startsWith("image/")) {
      throw new HttpsError("invalid-argument", "image must contain an image MIME type and base64 data.");
    }
    if (Buffer.byteLength(request.image.dataBase64, "utf8") > 7_000_000) {
      throw new HttpsError("invalid-argument", "Image exceeds the allowed size.");
    }
  }
  return {
    prompt: request.prompt,
    systemInstruction: request.systemInstruction,
    responseMimeType: request.responseMimeType === "application/json" ? "application/json" : "text/plain",
  };
}

/** User-initiated Gemini proxy. Request content and model output are never logged. */
export const generateAIContent = onCall(
  { secrets: [geminiApiKey], enforceAppCheck: true, timeoutSeconds: 60, memory: "512MiB" },
  async (request) => {
    requireAuthenticatedRequest(request.auth);
    const input = parseAIRequest(request.data);
    const client = new GoogleGenerativeAI(geminiApiKey.value());
    const model = client.getGenerativeModel({
      model: process.env.GEMINI_MODEL ?? "gemini-2.0-flash",
      systemInstruction: input.systemInstruction,
      generationConfig: { responseMimeType: input.responseMimeType },
    });
    try {
      const content = input.image
        ? [{ text: input.prompt }, { inlineData: { mimeType: input.image.mimeType, data: input.image.dataBase64 } }]
        : input.prompt;
      const result = await model.generateContent(content);
      return { text: result.response.text() };
    } catch {
      throw new HttpsError("unavailable", "AI processing is temporarily unavailable.");
    }
  },
);

/** Explicit clean-slate action for an account with a forgotten sync passphrase. */
export const resetEncryptedContent = onCall(
  { enforceAppCheck: true, timeoutSeconds: 540, memory: "1GiB" },
  async (request) => {
    requireAuthenticatedRequest(request.auth);
    const userId = request.auth.uid;
    await getFirestore().recursiveDelete(getFirestore().collection("users").doc(userId));
    await getStorage().bucket().deleteFiles({ prefix: `users/${userId}/` });
    return { reset: true };
  },
);
