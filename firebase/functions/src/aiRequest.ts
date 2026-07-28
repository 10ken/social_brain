export const MAX_PROMPT_BYTES = 250_000;
export const MAX_SYSTEM_INSTRUCTION_BYTES = 32_000;
export const MAX_TOTAL_TEXT_BYTES = 280_000;
export const MAX_IMAGE_BYTES = 5_000_000;

export type AIResponseMimeType = "application/json" | "text/plain";

export type AIRequest = {
  prompt: string;
  systemInstruction?: string;
  responseMimeType: AIResponseMimeType;
  image?: { mimeType: string; dataBase64: string };
};

export class AIRequestValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AIRequestValidationError";
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function validateBase64(value: string): boolean {
  return value.length > 0 && value.length % 4 === 0 && /^[A-Za-z0-9+/]*={0,2}$/.test(value);
}

/**
 * Validates data accepted by the callable endpoint without retaining or logging
 * user-provided content. Limits are expressed in decoded bytes where possible.
 */
export function parseAIRequest(value: unknown): AIRequest {
  if (!isRecord(value)) {
    throw new AIRequestValidationError("A request payload is required.");
  }

  const supportedKeys = new Set(["prompt", "systemInstruction", "responseMimeType", "image"]);
  if (Object.keys(value).some((key) => !supportedKeys.has(key))) {
    throw new AIRequestValidationError("The request contains an unsupported field.");
  }

  const prompt = value.prompt;
  if (typeof prompt !== "string" || prompt.trim().length === 0) {
    throw new AIRequestValidationError("A non-empty prompt is required.");
  }
  const promptBytes = Buffer.byteLength(prompt, "utf8");
  if (promptBytes > MAX_PROMPT_BYTES) {
    throw new AIRequestValidationError("Prompt exceeds the allowed size.");
  }

  const systemInstruction = value.systemInstruction;
  if (systemInstruction !== undefined && typeof systemInstruction !== "string") {
    throw new AIRequestValidationError("systemInstruction must be text.");
  }
  const systemInstructionBytes = systemInstruction === undefined
    ? 0
    : Buffer.byteLength(systemInstruction, "utf8");
  if (systemInstructionBytes > MAX_SYSTEM_INSTRUCTION_BYTES ||
    promptBytes + systemInstructionBytes > MAX_TOTAL_TEXT_BYTES) {
    throw new AIRequestValidationError("Text instructions exceed the allowed size.");
  }

  const requestedMimeType = value.responseMimeType ?? "text/plain";
  if (requestedMimeType !== "application/json" && requestedMimeType !== "text/plain") {
    throw new AIRequestValidationError("responseMimeType is not supported.");
  }

  const rawImage = value.image;
  let image: AIRequest["image"];
  if (rawImage !== undefined) {
    if (!isRecord(rawImage) || typeof rawImage.mimeType !== "string" ||
      typeof rawImage.dataBase64 !== "string" || !rawImage.mimeType.startsWith("image/")) {
      throw new AIRequestValidationError("image must contain an image MIME type and base64 data.");
    }
    if (!validateBase64(rawImage.dataBase64)) {
      throw new AIRequestValidationError("image data must be valid base64.");
    }
    const decodedImage = Buffer.from(rawImage.dataBase64, "base64");
    if (decodedImage.byteLength > MAX_IMAGE_BYTES) {
      throw new AIRequestValidationError("Image exceeds the allowed size.");
    }
    image = { mimeType: rawImage.mimeType, dataBase64: rawImage.dataBase64 };
  }

  return {
    prompt,
    systemInstruction,
    responseMimeType: requestedMimeType,
    image,
  };
}
