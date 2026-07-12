"use client";

type CompanionResponseProps = {
  opening: string;
  question: string;
  visible: boolean;
};

export function CompanionResponse({
  opening,
  question,
  visible,
}: CompanionResponseProps) {
  return (
    <div
      className={[
        "mt-10 w-full max-w-xl transition-all duration-[1400ms] ease-[cubic-bezier(0.22,1,0.36,1)]",
        visible
          ? "translate-y-0 opacity-100"
          : "pointer-events-none translate-y-2 opacity-0",
      ].join(" ")}
      aria-live="polite"
    >
      <p className="font-sans text-xl font-extralight leading-relaxed tracking-[0.04em] text-[var(--lb-fg-soft)] sm:text-2xl">
        {opening}
      </p>
      <p className="mt-4 font-sans text-xl font-extralight leading-relaxed tracking-[0.04em] text-[var(--lb-fg-soft)] sm:text-2xl">
        {question}
      </p>
    </div>
  );
}
