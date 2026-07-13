"use client";

/**
 * Client-side doorway to the LifeBook backend.
 * The Storykeeper's words go to the Archive; sessionStorage is no longer
 * memory — at most a local echo while the network breathes.
 */

export type ApiCompanionReply = {
  text: string;
};

async function json<T>(response: Response): Promise<T> {
  if (!response.ok) {
    const body = (await response.json().catch(() => null)) as {
      message?: string;
    } | null;
    throw new Error(body?.message ?? "We couldn't reach your story just now.");
  }
  return (await response.json()) as T;
}

export type ArrivalResult = {
  conversationId: string;
  draft: string | null;
};

export async function beginConversation(
  language: string,
): Promise<ArrivalResult> {
  const result = await json<{ conversationId: string; draft: string | null }>(
    await fetch("/api/conversation", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ language }),
    }),
  );
  return { conversationId: result.conversationId, draft: result.draft };
}

export async function entrustMoment(
  conversationId: string,
  text: string,
  language: string,
): Promise<ApiCompanionReply> {
  const result = await json<{ companion: { text: string } }>(
    await fetch(`/api/conversation/${conversationId}/moment`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ text, language }),
    }),
  );
  return { text: result.companion.text };
}

export async function saveDraft(
  conversationId: string,
  text: string,
): Promise<void> {
  await fetch(`/api/conversation/${conversationId}/draft`, {
    method: "PUT",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ text }),
  });
}

export async function restoreDraft(
  conversationId: string,
): Promise<string | null> {
  try {
    const result = await json<{ text: string | null }>(
      await fetch(`/api/conversation/${conversationId}/draft`),
    );
    return result.text;
  } catch {
    return null;
  }
}
