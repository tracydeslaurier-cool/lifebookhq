"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useEffect, useRef, useState } from "react";

/**
 * The doorway. Opening the emailed link lands here — on any device —
 * and brings the Storykeeper home. No form, no password, no chrome.
 */

type State = "opening" | "home" | "expired";

function Welcome() {
  const params = useSearchParams();
  const token = params.get("token");
  const [state, setState] = useState<State>(token ? "opening" : "expired");
  const openedRef = useRef(false);

  useEffect(() => {
    if (!token || openedRef.current) {
      return;
    }
    openedRef.current = true;

    fetch("/api/identity/complete", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ token }),
    })
      .then((response) => setState(response.ok ? "home" : "expired"))
      .catch(() => setState("expired"));
  }, [token]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-[var(--lb-bg)] px-6 text-center text-[var(--lb-fg)]">
      <div className="max-w-xl">
        {state === "opening" ? (
          <p className="font-sans text-2xl font-extralight tracking-[0.06em] text-[var(--lb-fg-soft)] transition-opacity duration-700">
            One moment…
          </p>
        ) : state === "home" ? (
          <>
            <h1 className="font-sans text-3xl font-extralight tracking-[0.08em] sm:text-4xl">
              Welcome home.
            </h1>
            <p className="mt-6 font-sans text-lg font-extralight leading-relaxed tracking-[0.04em] text-[var(--lb-fg-soft)]">
              Your story can find you now — here, and on any of your devices.
            </p>
            <Link
              href="/"
              className="mt-12 inline-block font-sans text-xl font-extralight tracking-[0.1em] underline-offset-8 transition-opacity duration-500 hover:opacity-75 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-8 focus-visible:outline-[var(--lb-fg-soft)]"
            >
              Continue your story
            </Link>
          </>
        ) : (
          <>
            <p className="font-sans text-2xl font-extralight leading-relaxed tracking-[0.06em] text-[var(--lb-fg-soft)]">
              This doorway has closed — they only stay open a little while.
            </p>
            <Link
              href="/"
              className="mt-12 inline-block font-sans text-xl font-extralight tracking-[0.1em] underline-offset-8 transition-opacity duration-500 hover:opacity-75"
            >
              Ask for another from your story
            </Link>
          </>
        )}
      </div>
    </div>
  );
}

export default function WelcomePage() {
  return (
    <Suspense>
      <Welcome />
    </Suspense>
  );
}
