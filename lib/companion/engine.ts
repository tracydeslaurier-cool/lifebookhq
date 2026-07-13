import type { BookTurn } from "@/lib/archive/reading";

/**
 * The Conversation Engine and the thought-engine loop, v0.
 * (foundation/directives/thought-engines.md)
 *
 * v0 runs the three faculties as a single disciplined model invocation —
 * explicitly permitted by the directive. The provider sits behind this
 * interface (P5): no provider format escapes this module.
 *
 * PROVIDER NOT YET SELECTED (Week 0 gate, IMPLEMENTATION_PLAN.md).
 * Until the Director signs no-training/no-retention terms, only the
 * DevelopmentStubProvider exists, and it must never face a Storykeeper.
 */

export type Composition = {
  text: string;
  modelId: string;
};

export interface CompanionProvider {
  compose(input: {
    /** The Book so far — Contextus's retrieval (whole Book in slice 1). */
    book: BookTurn[];
    /** The Moment just entrusted, or null when composing a homecoming. */
    latest: string | null;
    purpose: "conversation" | "homecoming";
    language: string;
  }): Promise<Composition>;
}

/**
 * DEV STUB — NOT A COMPANION.
 *
 * This exists only so the persistence loop can be exercised before the
 * provider decision. It does not listen, and pretending otherwise is the
 * exact trust violation the Foundation forbids — so it says so out loud.
 * It must be replaced before any real person uses LifeBook (spec §15.4).
 */
class DevelopmentStubProvider implements CompanionProvider {
  async compose(input: {
    book: BookTurn[];
    latest: string | null;
    purpose: "conversation" | "homecoming";
    language: string;
  }): Promise<Composition> {
    const text =
      input.purpose === "homecoming"
        ? "[dev stub] Welcome back. (The Companion's mind is not connected yet.)"
        : "[dev stub] Preserved. (The Companion's mind is not connected yet — this reply does not reflect what you shared.)";
    return { text, modelId: "dev-stub-0" };
  }
}

export function companionProvider(): CompanionProvider {
  // Provider selection is configuration, never engineering (Decision 017).
  // COMPANION_PROVIDER=anthropic is the PROVISIONAL development setting;
  // the blind audition selects production (AI_PROVIDER_EVALUATION.md).
  const configured = process.env.COMPANION_PROVIDER;

  if (configured === "anthropic") {
    // Deferred require keeps the adapter out of the bundle when unused.
    const {
      AnthropicCompanionProvider,
      // eslint-disable-next-line @typescript-eslint/no-require-imports
    } = require("@/lib/companion/providers/anthropic") as typeof import("@/lib/companion/providers/anthropic");
    return new AnthropicCompanionProvider();
  }

  if (process.env.NODE_ENV === "production") {
    throw new Error(
      "No Companion provider configured; the dev stub must never face a Storykeeper.",
    );
  }
  return new DevelopmentStubProvider();
}
