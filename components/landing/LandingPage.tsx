import Link from "next/link";

/**
 * The public face of LifeBook.
 *
 * This is the only page outside the staging gate, so it is the one thing a
 * stranger can see. It says what LifeBook is, honestly, and stops there.
 *
 * Held to DESIGN_PRINCIPLES: the interface disappears, the person remains.
 * No urgency, no FOMO, no feature grid. Every element earns its place.
 */

const PROMISES = [
  "Your words are kept as your words — not summarised, not scored.",
  "LifeBook remembers so you feel understood, never monitored.",
  "What you entrust stays yours, and leaves the moment you ask it to.",
];

export function LandingPage() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-between px-6 py-16 sm:px-8 sm:py-20">
      <div className="flex w-full max-w-xl flex-1 flex-col justify-center gap-14 py-12">
        <header className="flex flex-col gap-7">
          <h1 className="font-sans text-sm font-extralight tracking-[0.28em] text-[var(--lb-fg-muted)] uppercase">
            LifeBook
          </h1>

          <p className="font-serif text-4xl leading-[1.25] font-light text-balance text-[var(--lb-fg)] sm:text-5xl">
            A quiet place to be remembered.
          </p>

          <p className="max-w-prose text-base leading-relaxed text-[var(--lb-fg-soft)]">
            A life is not a file. LifeBook is a conversation that listens the
            way a good friend listens — without hurry, without a form to fill
            in — and keeps what you entrust to it for as long as you want it
            kept.
          </p>
        </header>

        <ul className="flex flex-col gap-4 border-l border-[var(--lb-border)] pl-6">
          {PROMISES.map((promise) => (
            <li
              key={promise}
              className="max-w-prose text-[0.95rem] leading-relaxed text-[var(--lb-fg-muted)]"
            >
              {promise}
            </li>
          ))}
        </ul>

        <section className="flex flex-col gap-4">
          <p className="max-w-prose text-[0.95rem] leading-relaxed text-[var(--lb-fg-muted)]">
            LifeBook is early, and deliberately so. We are in private
            conversation with a small number of Storykeepers, one at a time,
            because trust is not something to scale quickly.
          </p>

          <Link
            href="mailto:hello@lifebookhq.com?subject=LifeBook"
            className="w-fit border-b border-[var(--lb-accent)]/50 pb-1 font-serif text-xl font-light text-[var(--lb-accent)] transition-opacity duration-500 hover:opacity-70 focus-visible:opacity-70"
          >
            Write to us
          </Link>
        </section>
      </div>

      <footer className="flex w-full max-w-xl items-baseline justify-between gap-6 text-xs font-extralight tracking-[0.18em] text-[var(--lb-fg-muted)] uppercase opacity-50">
        <span>LifeBook</span>
        <span className="normal-case tracking-normal">Made in Edmonton</span>
      </footer>
    </main>
  );
}
