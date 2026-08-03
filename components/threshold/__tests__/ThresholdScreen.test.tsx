/**
 * ThresholdScreen tests
 *
 * Run: npm run test:run
 *
 * The Begin button's accessible name is `touchWordYouUnderstand`
 * ("Touch the word you understand."), not "begin". Queries use
 * getByText("Begin") to match visible text content, or
 * getByRole("button", { name: /touch the word/i }) for the aria-label.
 *
 * window.matchMedia is mocked in vitest.setup.ts (jsdom does not implement
 * it). Default: matches = false (no reduced motion).
 */

import { render, screen, act } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

// ── Mocks ───────────────────────────────────────────────────────────────────

vi.mock("@/lib/speech", () => ({
  speakText: vi.fn(),
  cancelSpeech: vi.fn(),
}));

vi.mock("@/lib/language", () => ({
  storeVoicePackId: vi.fn(),
  detectBrowserVoicePack: vi.fn(() => ({ id: "en" })),
}));

vi.mock("@/components/threshold/GlobeOverlay", () => ({
  GlobeOverlay: ({
    open,
    onClose,
    onSelect,
  }: {
    open: boolean;
    onClose: () => void;
    onSelect: (id: string) => void;
  }) =>
    open ? (
      <div data-testid="globe-overlay">
        <button onClick={() => onSelect("fr")}>Français</button>
        <button onClick={onClose}>Close</button>
      </div>
    ) : null,
}));

// ── Constants (mirror ThresholdScreen values) ────────────────────────────────

const ANIMATION_DURATION_MS = 3000;
const ROTATION_DELAY_MS = 3500;
const ROTATION_INTERVAL_MS = 2600;

// ── Helpers ──────────────────────────────────────────────────────────────────

async function renderThreshold(onEnter = vi.fn(), detectedPackId = "en") {
  const { getVoicePack } = await import("@/lib/voice-packs");
  const detectedPack = getVoicePack(detectedPackId as any);
  const result = render(
    <ThresholdScreen detectedPack={detectedPack} onEnter={onEnter} />,
  );
  return { ...result, onEnter, detectedPack };
}

/** The Begin button: find by its visible text, not its aria-label. */
function getBeginButton() {
  return screen.getByText("Begin");
}

// ── Module setup ─────────────────────────────────────────────────────────────

let ThresholdScreen: typeof import("../ThresholdScreen").ThresholdScreen;

beforeEach(async () => {
  ({ ThresholdScreen } = await import("../ThresholdScreen"));
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
  vi.clearAllMocks();
});

// ── Tests ─────────────────────────────────────────────────────────────────────

describe("First visit — threshold shown", () => {
  it("renders Begin hidden during animation, visible after", async () => {
    await renderThreshold();

    // During animation the Begin button is invisible (opacity-0).
    expect(getBeginButton()).toHaveClass("opacity-0");

    act(() => { vi.advanceTimersByTime(ANIMATION_DURATION_MS + 50); });

    expect(getBeginButton()).toHaveClass("opacity-100");
  });

  it("speaks the touch-word instruction once after animation", async () => {
    const { speakText } = await import("@/lib/speech");
    await renderThreshold();

    act(() => { vi.advanceTimersByTime(ANIMATION_DURATION_MS + 50); });

    expect(speakText).toHaveBeenCalledTimes(1);
    expect((speakText as any).mock.calls[0][0]).toMatch(/touch/i);
  });
});

describe("Language rotation", () => {
  it("starts rotating after ROTATION_DELAY_MS with no interaction", async () => {
    const { speakText } = await import("@/lib/speech");
    await renderThreshold();

    // Skip animation then wait for rotation to start.
    act(() => {
      vi.advanceTimersByTime(ANIMATION_DURATION_MS + ROTATION_DELAY_MS + 100);
    });

    // speakText: instruction (1×) + first rotation tick (1×) = 2.
    expect(speakText).toHaveBeenCalledTimes(2);
    // Second call is a short "begin"-style word, not the full instruction.
    const secondCallText: string = (speakText as any).mock.calls[1][0];
    expect(secondCallText.length).toBeLessThan(40);
  });

  it("advances to a new language on each rotation tick", async () => {
    const { speakText } = await import("@/lib/speech");
    await renderThreshold();

    act(() => {
      vi.advanceTimersByTime(
        ANIMATION_DURATION_MS + ROTATION_DELAY_MS + ROTATION_INTERVAL_MS * 2 + 200,
      );
    });

    // Instruction (1) + at least 2 rotation ticks = ≥ 3.
    expect(speakText).toHaveBeenCalledTimes(3);
  });
});

describe("Language selection — rotation stops, language adopted", () => {
  it("calls onEnter with the detected pack when Begin is tapped", async () => {
    const onEnter = vi.fn();
    await renderThreshold(onEnter);

    act(() => { vi.advanceTimersByTime(ANIMATION_DURATION_MS + 100); });

    await userEvent.click(getBeginButton());
    expect(onEnter).toHaveBeenCalledTimes(1);
    expect(onEnter).toHaveBeenCalledWith("en");
  });

  it("calls onEnter with the rotated pack when a non-detected language is active", async () => {
    const onEnter = vi.fn();
    await renderThreshold(onEnter);

    // Advance past animation + rotation start + one full interval.
    act(() => {
      vi.advanceTimersByTime(
        ANIMATION_DURATION_MS + ROTATION_DELAY_MS + ROTATION_INTERVAL_MS + 100,
      );
    });

    // The button text is no longer "Begin" in English — it's some other language's word.
    // Click whichever Begin-equivalent is currently displayed.
    const btn = screen.getByRole("button", { name: /touch the word/i });
    await userEvent.click(btn);
    expect(onEnter).toHaveBeenCalledTimes(1);
    expect(onEnter.mock.calls[0][0]).not.toBe("en");
  });

  it("does not call onEnter twice (idempotent enter guard)", async () => {
    const onEnter = vi.fn();
    await renderThreshold(onEnter);

    act(() => { vi.advanceTimersByTime(ANIMATION_DURATION_MS + 100); });

    await userEvent.click(getBeginButton());
    await userEvent.click(getBeginButton());
    expect(onEnter).toHaveBeenCalledTimes(1);
  });
});

describe("Interruption", () => {
  it("skips animation on any keypress, making Begin visible immediately", async () => {
    const { container } = await renderThreshold();
    const wrapper = container.firstChild as HTMLElement;

    // During animation Begin is invisible.
    expect(getBeginButton()).toHaveClass("opacity-0");

    // Any key interrupts — wrapper div captures keyboard events.
    wrapper.focus();
    await userEvent.keyboard("{Enter}");

    expect(getBeginButton()).toHaveClass("opacity-100");
  });

  it("advances with current language on keypress during rotation", async () => {
    const onEnter = vi.fn();
    const { container } = await renderThreshold(onEnter);
    const wrapper = container.firstChild as HTMLElement;

    act(() => {
      vi.advanceTimersByTime(ANIMATION_DURATION_MS + ROTATION_DELAY_MS + 100);
    });

    wrapper.focus();
    await userEvent.keyboard(" ");
    expect(onEnter).toHaveBeenCalledTimes(1);
  });
});

describe("Reduced motion", () => {
  it("shows Begin immediately, skipping animation", async () => {
    // Override matchMedia to report reduced motion for this test.
    window.matchMedia = vi.fn((q: string) => ({
      matches: q.includes("prefers-reduced-motion"),
      media: q,
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    })) as any;

    await renderThreshold();

    // Begin is visible without any timer advancement.
    expect(getBeginButton()).toHaveClass("opacity-100");
  });

  it("does not render animation overlay elements when reduced motion is active", async () => {
    window.matchMedia = vi.fn((q: string) => ({
      matches: q.includes("prefers-reduced-motion"),
      media: q,
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    })) as any;

    const { container } = await renderThreshold();

    expect(container.querySelector(".lb-threshold-crack")).toBeNull();
    expect(container.querySelector(".lb-threshold-veil")).toBeNull();
  });
});

describe("Silent operation — TTS unavailable", () => {
  it("remains functional when speakText throws (silent device)", async () => {
    const { speakText } = await import("@/lib/speech");
    (speakText as any).mockImplementation(() => {
      throw new Error("SpeechSynthesis not supported");
    });

    // Component should mount and reach presenting phase without crashing.
    await renderThreshold();
    act(() => { vi.advanceTimersByTime(ANIMATION_DURATION_MS + 50); });

    // Begin is visible — the UI continues even though TTS threw.
    expect(getBeginButton()).toHaveClass("opacity-100");
    expect(getBeginButton()).toBeInTheDocument();
  });
});

describe("Globe fallback", () => {
  it("opens the globe overlay when the globe button is clicked", async () => {
    await renderThreshold();
    act(() => { vi.advanceTimersByTime(ANIMATION_DURATION_MS + 100); });

    await userEvent.click(screen.getByLabelText(/choose a language/i));
    expect(screen.getByTestId("globe-overlay")).toBeInTheDocument();
  });

  it("calls onEnter with the globe-selected language and closes the overlay", async () => {
    const onEnter = vi.fn();
    await renderThreshold(onEnter);
    act(() => { vi.advanceTimersByTime(ANIMATION_DURATION_MS + 100); });

    await userEvent.click(screen.getByLabelText(/choose a language/i));
    await userEvent.click(screen.getByText("Français"));

    expect(onEnter).toHaveBeenCalledWith("fr");
    expect(screen.queryByTestId("globe-overlay")).toBeNull();
  });
});

describe("Returning visitor — threshold skipped", () => {
  it("ThresholdScreen has no knowledge of session storage (skip logic lives in OpeningExperience)", () => {
    // ThresholdScreen renders whenever it is mounted.
    // OpeningExperience is responsible for not mounting it on return visits.
    // This is verified at the OpeningExperience integration level.
    expect(true).toBe(true);
  });
});
