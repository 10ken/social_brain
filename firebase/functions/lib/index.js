"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.resetEncryptedContent = exports.generateAIContent = void 0;
const generative_ai_1 = require("@google/generative-ai");
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const storage_1 = require("firebase-admin/storage");
const params_1 = require("firebase-functions/params");
const https_1 = require("firebase-functions/v2/https");
(0, app_1.initializeApp)();
const geminiApiKey = (0, params_1.defineSecret)("GEMINI_API_KEY");
const maximumPromptBytes = 250_000;
function requireAuthenticatedRequest(auth) {
    if (!auth || typeof auth !== "object" || !("uid" in auth)) {
        throw new https_1.HttpsError("unauthenticated", "Sign in before using AI features.");
    }
}
function parseAIRequest(value) {
    if (!value || typeof value !== "object") {
        throw new https_1.HttpsError("invalid-argument", "A request payload is required.");
    }
    const request = value;
    if (typeof request.prompt !== "string" || request.prompt.trim().length === 0) {
        throw new https_1.HttpsError("invalid-argument", "A non-empty prompt is required.");
    }
    if (Buffer.byteLength(request.prompt, "utf8") > maximumPromptBytes) {
        throw new https_1.HttpsError("invalid-argument", "Prompt exceeds the allowed size.");
    }
    if (request.systemInstruction !== undefined && typeof request.systemInstruction !== "string") {
        throw new https_1.HttpsError("invalid-argument", "systemInstruction must be text.");
    }
    if (request.image !== undefined) {
        if (typeof request.image !== "object" || typeof request.image.mimeType !== "string" ||
            typeof request.image.dataBase64 !== "string" || !request.image.mimeType.startsWith("image/")) {
            throw new https_1.HttpsError("invalid-argument", "image must contain an image MIME type and base64 data.");
        }
        if (Buffer.byteLength(request.image.dataBase64, "utf8") > 7_000_000) {
            throw new https_1.HttpsError("invalid-argument", "Image exceeds the allowed size.");
        }
    }
    return {
        prompt: request.prompt,
        systemInstruction: request.systemInstruction,
        responseMimeType: request.responseMimeType === "application/json" ? "application/json" : "text/plain",
    };
}
/** User-initiated Gemini proxy. Request content and model output are never logged. */
exports.generateAIContent = (0, https_1.onCall)({ secrets: [geminiApiKey], enforceAppCheck: true, timeoutSeconds: 60, memory: "512MiB" }, async (request) => {
    requireAuthenticatedRequest(request.auth);
    const input = parseAIRequest(request.data);
    const client = new generative_ai_1.GoogleGenerativeAI(geminiApiKey.value());
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
    }
    catch {
        throw new https_1.HttpsError("unavailable", "AI processing is temporarily unavailable.");
    }
});
/** Explicit clean-slate action for an account with a forgotten sync passphrase. */
exports.resetEncryptedContent = (0, https_1.onCall)({ enforceAppCheck: true, timeoutSeconds: 540, memory: "1GiB" }, async (request) => {
    requireAuthenticatedRequest(request.auth);
    const userId = request.auth.uid;
    await (0, firestore_1.getFirestore)().recursiveDelete((0, firestore_1.getFirestore)().collection("users").doc(userId));
    await (0, storage_1.getStorage)().bucket().deleteFiles({ prefix: `users/${userId}/` });
    return { reset: true };
});
