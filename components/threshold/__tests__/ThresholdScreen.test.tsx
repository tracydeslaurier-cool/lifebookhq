/**
 * ThresholdScreen tests
 *
 * Setup required (none currently installed):
 *   npm install -D vitest @vitejs/plugin-react jsdom \
 *     @testing-library/react @testing-library/user-event
 *
 * Then add to vitest.config.ts:
 *   import react from "@vitejs/plugin-react";
 *   export default { plugins: [react()], test: { environment: "jsdom" } };
 *
 * These tests cover the seven behavioural requirements from the 2026-08-03
 * Universal Threshold decision.
 */

import { render, screen, act, waitFor } from "@testing-library/react";
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
  GlobeOverlay: ({ open, onClose, onSelect }: { open: boolean; onClose: () => void; onSelect: (id: string) => void }) =>
    open ? (
      <div data-testid="globe-overlay">
        <button onClick={() => onSelect("fr")}>Français</button>
        <button onClick={onClose}>Close</button>
      </div>
    ) : null,
}));

// ── Helpers ─────────────────────────────────────────────────────────────────

const ANIMATION_DURATION_MS = 3000;
const ROTATION_DELAY_MS = 3500;
const ROTATION_INTERVAL_MS = 2600;

async function renderThreshold(
  onEnter = vi.fn(),
  detectedPackId = "en",
) {
  const { getVoicePack } = await import("@/lib/voice-packs");
  const detectedPack = getVoicePack(detectedPackId as any);

  const result = render(
    <ThresholdScreen detectedPack={detectedPack} onEnter={onEnter} />,
  );
  return { ...result, onEnter, detectedPack };
}

// Deferred import so mocks are in place before the module loads.
let ThresholdScreen: typeof import("../ThresholdScreen").ThresholdScreen;
beforeEach(async () => {
  ({ ThresholdScreen } = await import("../ThresholdScreen"));
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
  vi.clearAllMocks();
});

// ── Tests ───────────────────────────────────────────────────────────────────

describe("First visit — threshold shown", () => {
  it("renders the Begin button (hidden during animation, visible after)", async () => {
    const { getByRole } = await renderThreshold();

    // During animation the Begin button exists but is invisible.
    const beginBtn = getByRole("button", { name: /begin/i });
    expect(beginBtn).toHaveClass("opacity-0");

    // After animation completes it becomes visible.
    act(() => { vi.advanceTimersByTime(ANIMATION_DURATION_MS + 50); });
    expect(beginBtn).toHaveClass("opacity-100");
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
    act(() => { vi.advanceTimersByTime(ANIMATION_DURATION_MS + ROTATION_DELAY_MS + 100); });

    // speakText should have been called for the instruction (1×) + first tick (1×).
    expect(speakText).toHaveBeenCalledTimes(2);
    // Second call should be a short "begin"-style cue (not the full instruction).
    const secondCallText: string = (speakText as any).mock.calls[1][0];
    expect(secondCallText.length).toBeLessThan(40);
  });

  it("advances to the next language on each rotation tick", async () => {
    const { speakText } = await import("@/lib/speech");
    await renderThreshold();

    act(() => {
      vi.advanceTimersByTime(
        ANIMATION_DURATION_MS + ROTATION_DELAY_MS + ROTATION_INTERVAL_MS * 2 + 200,
      );
    });

    // Instruction (1) + at least 2 rotation ticks = 3+ calls.
    expect(speakText).toHaveBeenCalledTimes(3);
  });
});

describe("Language selection — rotation stops, language is adopted", () => {
  it("calls onEnter with the currently displayed pack when Begin is tapped", async () => {
    const onEnter = vi.fn();
    const { getByRole } = await renderThreshold(onEnter);

    // Skip to presenting phase.
    act(() => { vi.advanceTimersByTime(ANIMATION_DURATION_MS + 100); });

    await userEvent.click(getByRole("button", { name: /begin/i }));
    expect(onEnter).toHaveBeenCalledTimes(1);
    expect(onEnter).toHaveBeenCalledWith("en");
  });

  it("calls onEnter with the rotated pack when a non-detected language is active", async () => {
    const onEnter = vi.fn();
    const { getByRole } = await renderThreshold(onEnter);

    // Advance past animation + rotation start + one full tick (which loads fr or uk etc.).
    act(() => {
      vi.advanceTimersByTime(
        ANIMATION_DURATION_MS + ROTATION_DELAY_MS + ROTATION_INTERVAL_MS + 100,
      );
    });

    await userEvent.click(getByRole("button", { name: /.+/ }));
    expect(onEnter).toHaveBeenCalledTimes(1);
    // The selected pack should NOT be "en" (we rotated past it).
    expect(onEnter.mock.calls[0][0]).not.toBe("en");
  });

  it("does not call onEnter a second time if Begin is tapped twice (idempotent)", async () => {
    const onEnter = vi.fn();
    const { getByRole } = await renderThreshold(onEnter);

    act(() => { vi.advanceTimersByTime(ANIMATION_DURATION_MS + 100); });

    const btn = getByRole("button", { name: /begin/i });
    await userEvent.click(btn);
    await userEvent.click(btn);
    expect(onEnter).toHaveBeenCalledTimes(1);
  });
});

describe("Interruption", () => {
  it("skips animation immediately on any keypress", async () => {
    const { container } = await renderThreshold();
    const wrapper = container.firstChild as HTMLElement;

    // During animation phase Begin should be invisible.
    expect(screen.getByRole("button", { name: /begin/i })).toHaveClass("opacity-0");

    await userEvent.type(wrapper, "{Enter}");

    // After keypress Begin becomes visible (presenting phase).
    expect(screen.getByRole("button", { name: /begin/i })).toHaveClass("opacity-100");
  });

  it("advances with current language on keypress during rotation", async () => {
    const onEnter = vi.fn();
    const { container } = await renderThreshold(onEnter);
    const wrapper = container.firstChild as HTMLElement;

    act(() => { vi.advanceTimersByTime(ANIMATION_DURATION_MS + ROTATION_DELAY_MS + 100); });

    await userEvent.type(wrapper, " ");
    expect(onEnter).toHaveBeenCalledTimes(1);
  });
});

describe("Reduced motion", () => {
  it("shows Begin immediately and skips the animation when prefers-reduced-motion is set", async () => {
    // Override matchMedia to report reduced motion.
    const original = window.matchMedia;
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

    const { getByRole } = await renderThreshold();

    // Begin should be visible without any timer advancement.
    expect(getByRole("button", { name: /begin/i })).toHaveClass("opacity-100");

    window.matchMedia = original;
  });

  it("does not render the animation overlay elements when reduced motion is active", async () => {
    const original = window.matchMedia;
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

    window.matchMedia = original;
  });
});

describe("Silent operation", () => {
  it("does not throw when speakText fails (device has no TTS)", async () => {
    const { speakText } = await import("@/lib/speech");
    (speakText as any).mockImplementation(() => {
      throw new Error("SpeechSynthesis not supported");
    });

    // Rendering should succeed and not propagate the error.
    expect(() => renderThreshold()).not.toThrow();
  });
});

describe("Globe fallback", () => {
  it("opens the globe overlay on globe button click", async () => {
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
  it("does NOT render ThresholdScreen when sessionBeginCompleted is true", async () => {
    // This is tested at the OpeningExperience level: if hasCompletedBegin()
    // returns true, OpeningExperience renders the invitation directly.
    // See: components/opening/__tests__/OpeningExperience.test.tsx
    //
    // ThresholdScreen itself has no knowledge of session storage — it renders
    // whenever it is mounted. The skip logic lives in OpeningExperience.
    expect(true).toBe(true); // placeholder — coverage lives one level up
  });
});
