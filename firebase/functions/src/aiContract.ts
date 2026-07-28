export const MAX_AI_RESPONSE_BYTES = 1_000_000;

export type ConfidenceState = "suggested" | "needs_review";
export type MemoryType =
  | "life_update"
  | "preference"
  | "relationship"
  | "event_context"
  | "follow_up"
  | "general_note";
export type RelationshipType = "spouse" | "sibling" | "coworker" | "friend" | "met_through";

export type ExtractedPerson = {
  name: string;
  confidenceState: ConfidenceState;
  evidence: string;
};

export type ExtractedEvent = {
  title: string;
  dateText?: string | null;
  resolvedDate?: string | null;
  timeText?: string | null;
  location?: string | null;
  people?: string[];
  confidenceState: ConfidenceState;
  evidence: string;
};

export type ExtractedMemory = {
  person?: string | null;
  content: string;
  memoryType: MemoryType;
  confidenceState: ConfidenceState;
  evidence: string;
};

export type ExtractedRelationship = {
  personA: string;
  personB: string;
  relationshipType: RelationshipType;
  confidenceState: ConfidenceState;
  evidence: string;
};

export type ExtractedReminder = {
  title: string;
  dueText?: string | null;
  confidenceState: ConfidenceState;
  evidence: string;
};

export type AIExtractionResult = {
  people: ExtractedPerson[];
  events: ExtractedEvent[];
  memories: ExtractedMemory[];
  relationships: ExtractedRelationship[];
  reminders: ExtractedReminder[];
};

export class AIContractValidationError extends Error {
  constructor() {
    super("AI output did not match the extraction contract.");
    this.name = "AIContractValidationError";
  }
}

export class AIResponseSizeError extends Error {
  constructor() {
    super("AI output exceeded the allowed size.");
    this.name = "AIResponseSizeError";
  }
}

type JsonRecord = Record<string, unknown>;

const confidenceStates = new Set<ConfidenceState>(["suggested", "needs_review"]);
const memoryTypes = new Set<MemoryType>([
  "life_update",
  "preference",
  "relationship",
  "event_context",
  "follow_up",
  "general_note",
]);
const relationshipTypes = new Set<RelationshipType>([
  "spouse",
  "sibling",
  "coworker",
  "friend",
  "met_through",
]);
const topLevelKeys = ["people", "events", "memories", "relationships", "reminders"];
const maxSuggestionsPerType = 100;

function isRecord(value: unknown): value is JsonRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function hasOnlyKeys(value: JsonRecord, allowedKeys: readonly string[]): boolean {
  return Object.keys(value).every((key) => allowedKeys.includes(key));
}

function isText(value: unknown, minLength = 1, maxLength = 2_000): value is string {
  return typeof value === "string" && value.length >= minLength && value.length <= maxLength;
}

function isOptionalText(value: unknown, maxLength = 2_000): boolean {
  return value === undefined || value === null || isText(value, 0, maxLength);
}

function isDate(value: unknown): boolean {
  if (value === undefined || value === null) return true;
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}

function hasSuggestionBase(value: JsonRecord): boolean {
  return confidenceStates.has(value.confidenceState as ConfidenceState) && isText(value.evidence);
}

function isPeopleList(value: unknown): boolean {
  return value === undefined || (
    Array.isArray(value) && value.length <= maxSuggestionsPerType &&
    value.every((name) => isText(name, 1, 300))
  );
}

function isPerson(value: unknown): value is ExtractedPerson {
  return isRecord(value) &&
    hasOnlyKeys(value, ["name", "confidenceState", "evidence"]) &&
    isText(value.name, 1, 300) && hasSuggestionBase(value);
}

function isEvent(value: unknown): value is ExtractedEvent {
  return isRecord(value) &&
    hasOnlyKeys(value, [
      "title", "dateText", "resolvedDate", "timeText", "location", "people", "confidenceState", "evidence",
    ]) &&
    isText(value.title, 1, 500) &&
    isOptionalText(value.dateText) && isDate(value.resolvedDate) &&
    isOptionalText(value.timeText) && isOptionalText(value.location) &&
    isPeopleList(value.people) && hasSuggestionBase(value);
}

function isMemory(value: unknown): value is ExtractedMemory {
  return isRecord(value) &&
    hasOnlyKeys(value, ["person", "content", "memoryType", "confidenceState", "evidence"]) &&
    isOptionalText(value.person, 300) && isText(value.content, 1, 10_000) &&
    memoryTypes.has(value.memoryType as MemoryType) && hasSuggestionBase(value);
}

function isRelationship(value: unknown): value is ExtractedRelationship {
  return isRecord(value) &&
    hasOnlyKeys(value, ["personA", "personB", "relationshipType", "confidenceState", "evidence"]) &&
    isText(value.personA, 1, 300) && isText(value.personB, 1, 300) &&
    relationshipTypes.has(value.relationshipType as RelationshipType) && hasSuggestionBase(value);
}

function isReminder(value: unknown): value is ExtractedReminder {
  return isRecord(value) &&
    hasOnlyKeys(value, ["title", "dueText", "confidenceState", "evidence"]) &&
    isText(value.title, 1, 500) && isOptionalText(value.dueText) && hasSuggestionBase(value);
}

function isSuggestionList<T>(value: unknown, validator: (item: unknown) => item is T): value is T[] {
  return Array.isArray(value) && value.length <= maxSuggestionsPerType && value.every(validator);
}

/** Returns true only for data that conforms to shared/contracts/v1. */
export function isAIExtractionResult(value: unknown): value is AIExtractionResult {
  return isRecord(value) && hasOnlyKeys(value, topLevelKeys) &&
    isSuggestionList(value.people, isPerson) &&
    isSuggestionList(value.events, isEvent) &&
    isSuggestionList(value.memories, isMemory) &&
    isSuggestionList(value.relationships, isRelationship) &&
    isSuggestionList(value.reminders, isReminder);
}

/** Bounds every model response before it can be returned to a mobile client. */
export function ensureAIResponseWithinLimit(text: string): void {
  if (Buffer.byteLength(text, "utf8") > MAX_AI_RESPONSE_BYTES) {
    throw new AIResponseSizeError();
  }
}

/** Parses and validates JSON-model output without ever including it in an error. */
export function parseAIExtractionOutput(text: string): AIExtractionResult {
  ensureAIResponseWithinLimit(text);
  try {
    const parsed: unknown = JSON.parse(text);
    if (isAIExtractionResult(parsed)) return parsed;
  } catch {
    // Model output is intentionally not logged or included in the client error.
  }
  throw new AIContractValidationError();
}
