import { vi } from "vitest";

/**
 * Global test environment setup.
 *
 * jsdom does not implement window.matchMedia. Every test that renders
 * ThresholdScreen needs this stub or the component throws on mount.
 * Default: matches = false (no reduced motion, no dark mode, etc.).
 * Individual tests that want to simulate reduced motion can reassign
 * window.matchMedia locally.
 */
Object.defineProperty(window, "matchMedia", {
  writable: true,
  value: vi.fn((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
});
