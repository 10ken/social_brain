/** The deployment can override this through the non-secret GEMINI_MODEL setting. */
export const DEFAULT_GEMINI_MODEL = "gemini-3.6-flash";

/** Falls back safely when GEMINI_MODEL is absent or accidentally blank. */
export function resolveGeminiModel(configuredModel: string | undefined): string {
  return configuredModel?.trim() || DEFAULT_GEMINI_MODEL;
}

export function getGeminiModel(): string {
  return resolveGeminiModel(process.env.GEMINI_MODEL);
}
