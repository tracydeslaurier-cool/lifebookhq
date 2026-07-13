import type { BookTurn } from "@/lib/archive/reading";
import { buildSystemPrompt } from "@/lib/companion/contract";
import type { CompanionProvider, Composition } from "@/lib/companion/engine";

/**
 * PROVISIONAL development adapter — Anthropic Messages API.
 * (AI_PROVIDER_EVALUATION.md, "Development Provider".)
 *
 * The blind Companion audition selects the production provider; replacing
 * this adapter is a configuration exercise (Decision 017). Uses plain fetch —
 * no SDK — so nothing provider-shaped leaks past this file. The entrusted
 * plane never stores anything from this response except the composed text
 * and the model identifier (provenance).
 */

const API_URL = "https://api.anthropic.com/v1/messages";
const API_VERSION = "2023-06-01";
const DEFAULT_MODEL = "claude-sonnet-5";
const MAX_REPLY_TOKENS = 400;

type AnthropicMessage = { role: "user" | "assistant"; content: string };

function toMessages(
  book: BookTurn[],
  latest: string | null,
  purpose: "conversation" | "homecoming",
): AnthropicMessage[] {
  const messages: AnthropicMessage[] = [];

  for (const turn of book) {
    messages.push({
      role: turn.speaker === "storykeeper" ? "user" : "assistant",
      content: turn.text,
    });
  }

  // The Book already contains the just-entrusted Moment (the Archive wrote it
  // before composition). Guard anyway: if the latest words are missing from
  // the record we were given, append them — the Companion must never answer
  // without having "heard" the thought it is answering.
  if (latest && messages[messages.length - 1]?.content !== latest) {
    messages.push({ role: "user", content: latest });
  }

  if (purpose === "homecoming") {
    messages.push({
      role: "user",
      content:
        "[The Storykeeper has just returned to LifeBook. Greet them.]",
    });
  }

  // Anthropic requires alternating roles starting with "user"; merge any
  // consecutive same-role turns (e.g., two Moments without a reply between).
  const merged: AnthropicMessage[] = [];
  for (const message of messages) {
    const previous = merged[merged.length - 1];
    if (previous && previous.role === message.role) {
      previous.content = `${previous.content}\n\n${message.content}`;
    } else {
      merged.push({ ...message });
    }
  }
  if (merged.length === 0 || merged[0].role !== "user") {
    merged.unshift({ role: "user", content: "[The conversation begins.]" });
  }

  return merged;
}

export class AnthropicCompanionProvider implements CompanionProvider {
  async compose(input: {
    book: BookTurn[];
    latest: string | null;
    purpose: "conversation" | "homecoming";
    language: string;
  }): Promise<Composition> {
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      throw new Error("ANTHROPIC_API_KEY is not set");
    }
    const model = process.env.COMPANION_MODEL ?? DEFAULT_MODEL;

    const response = await fetch(API_URL, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": API_VERSION,
      },
      body: JSON.stringify({
        model,
        max_tokens: MAX_REPLY_TOKENS,
        system: buildSystemPrompt({
          purpose: input.purpose,
          language: input.language,
        }),
        messages: toMessages(input.book, input.latest, input.purpose),
      }),
    });

    if (!response.ok) {
      const detail = await response.text().catch(() => "");
      throw new Error(
        `Companion provider error (${response.status}): ${detail.slice(0, 200)}`,
      );
    }

    const body = (await response.json()) as {
      model?: string;
      content?: Array<{ type: string; text?: string }>;
    };
    const text = (body.content ?? [])
      .filter((block) => block.type === "text" && typeof block.text === "string")
      .map((block) => block.text)
      .join("")
      .trim();

    if (!text) {
      throw new Error("Companion provider returned an empty composition");
    }

    return { text, modelId: body.model ?? model };
  }
}
