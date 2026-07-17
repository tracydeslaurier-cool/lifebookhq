"use client";

import type { Replayer as ReplayerType } from "rrweb";
import { useCallback, useEffect, useRef, useState } from "react";

/**
 * The Threshold replay viewer — part of the Discovery toolkit, not the product.
 * Facilitator-only (behind EXPERIMENT_VIEWER_KEY). Plays back masked rrweb
 * recordings so remote sessions can be observed: where a person hesitated,
 * what they reached for, when they crossed the threshold. Behaviour only —
 * every word and input was masked in the browser before it was ever stored.
 */

type RecordedSession = {
  sessionId: string;
  variant: string;
  startedAt: string;
  batchCount: number;
  entrusted: boolean;
};

const SPEEDS = [1, 2, 4];

export default function ReplayPage() {
  const [sessions, setSessions] = useState<RecordedSession[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [status, setStatus] = useState("Loading sessions…");
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState(1);

  const containerRef = useRef<HTMLDivElement>(null);
  const replayerRef = useRef<ReplayerType | null>(null);

  useEffect(() => {
    fetch("/api/experiment/replay/sessions")
      .then((response) => response.json())
      .then((data: { sessions?: RecordedSession[] }) => {
        const list = data.sessions ?? [];
        setSessions(list);
        setStatus(list.length === 0 ? "No recordings yet." : "");
      })
      .catch(() => setStatus("Could not load sessions."));
  }, []);

  useEffect(() => {
    if (!selected) return;
    let disposed = false;
    setPlaying(false);
    setStatus("Loading recording…");
    replayerRef.current?.pause();
    replayerRef.current = null;
    if (containerRef.current) containerRef.current.innerHTML = "";

    fetch(`/api/experiment/replay/${selected}`)
      .then((response) => response.json())
      .then(async (data: { events?: unknown[] }) => {
        if (disposed) return;
        const events = data.events ?? [];
        if (events.length < 2) {
          setStatus("This recording is too short to play.");
          return;
        }
        const { Replayer } = await import("rrweb");
        if (disposed || !containerRef.current) return;
        const replayer = new Replayer(
          events as ConstructorParameters<typeof Replayer>[0],
          { root: containerRef.current, speed, skipInactive: true },
        );
        replayerRef.current = replayer;
        setStatus("");
      })
      .catch(() => {
        if (!disposed) setStatus("Could not load this recording.");
      });

    return () => {
      disposed = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selected]);

  const togglePlay = useCallback(() => {
    const replayer = replayerRef.current;
    if (!replayer) return;
    if (playing) {
      replayer.pause();
      setPlaying(false);
    } else {
      replayer.play(replayer.getCurrentTime());
      setPlaying(true);
    }
  }, [playing]);

  const restart = useCallback(() => {
    const replayer = replayerRef.current;
    if (!replayer) return;
    replayer.play(0);
    setPlaying(true);
  }, []);

  const changeSpeed = useCallback((next: number) => {
    setSpeed(next);
    replayerRef.current?.setConfig({ speed: next });
  }, []);

  return (
    <div className="flex min-h-screen bg-[var(--lb-bg)] text-[var(--lb-fg)]">
      <aside className="w-72 shrink-0 overflow-y-auto border-r border-[var(--lb-border)] p-4">
        <h1 className="mb-4 font-sans text-sm font-extralight tracking-[0.14em] text-[var(--lb-fg-soft)]">
          THRESHOLD · REPLAYS
        </h1>
        {sessions.length === 0 ? (
          <p className="font-sans text-xs font-extralight text-[var(--lb-fg-muted)]">
            {status}
          </p>
        ) : null}
        <ul className="space-y-1">
          {sessions.map((session) => (
            <li key={session.sessionId}>
              <button
                type="button"
                onClick={() => setSelected(session.sessionId)}
                className={[
                  "w-full rounded px-3 py-2 text-left font-sans text-xs font-extralight leading-relaxed tracking-[0.04em] transition-colors duration-300",
                  selected === session.sessionId
                    ? "bg-[color:rgba(242,236,228,0.08)] text-[var(--lb-fg)]"
                    : "text-[var(--lb-fg-muted)] hover:text-[var(--lb-fg-soft)]",
                ].join(" ")}
              >
                <span className="mr-2 inline-block rounded border border-[var(--lb-border)] px-1.5 py-0.5 uppercase">
                  {session.variant}
                </span>
                {session.entrusted ? (
                  <span className="text-[var(--lb-accent)]">✦ entrusted</span>
                ) : (
                  <span className="opacity-50">— no entrustment</span>
                )}
                <br />
                <span className="opacity-70">
                  {new Date(session.startedAt).toLocaleString()}
                </span>
              </button>
            </li>
          ))}
        </ul>
      </aside>

      <main className="flex min-w-0 flex-1 flex-col">
        <div className="flex items-center gap-4 border-b border-[var(--lb-border)] px-6 py-3">
          <button
            type="button"
            onClick={togglePlay}
            disabled={!selected}
            className="font-sans text-sm font-extralight tracking-[0.14em] text-[var(--lb-fg-soft)] transition-colors duration-300 hover:text-[var(--lb-fg)] disabled:opacity-30"
          >
            {playing ? "Pause" : "Play"}
          </button>
          <button
            type="button"
            onClick={restart}
            disabled={!selected}
            className="font-sans text-sm font-extralight tracking-[0.14em] text-[var(--lb-fg-muted)] transition-colors duration-300 hover:text-[var(--lb-fg)] disabled:opacity-30"
          >
            Restart
          </button>
          <div className="ml-4 flex items-center gap-3">
            {SPEEDS.map((option) => (
              <button
                key={option}
                type="button"
                onClick={() => changeSpeed(option)}
                className={[
                  "font-sans text-xs font-extralight tracking-[0.1em] transition-colors duration-300",
                  speed === option
                    ? "text-[var(--lb-fg)]"
                    : "text-[var(--lb-fg-muted)] hover:text-[var(--lb-fg-soft)]",
                ].join(" ")}
              >
                {option}×
              </button>
            ))}
          </div>
          {status ? (
            <span className="ml-auto font-sans text-xs font-extralight text-[var(--lb-fg-muted)]">
              {status}
            </span>
          ) : null}
        </div>

        <div className="flex-1 overflow-auto p-6">
          {!selected ? (
            <p className="font-sans text-sm font-extralight leading-relaxed text-[var(--lb-fg-muted)]">
              Select a session to replay. Recordings show behaviour only — every
              word and input is masked.
            </p>
          ) : null}
          <div ref={containerRef} className="mx-auto w-fit" />
        </div>
      </main>
    </div>
  );
}
