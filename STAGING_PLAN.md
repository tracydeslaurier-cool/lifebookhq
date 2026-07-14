# Staging Plan — The First Doorway Beyond the Building

Status: APPROVED DIRECTION (Director, 2026-07-16) — Stage 1 in progress. Nothing deployed until Stages 0–5 complete in order. Sequencing per the Director: complete Stage 1, prove deletion and export, deploy staging, Tracy and Iryna walk it once — *then* Olya. "She deserves to experience LifeBook when it already feels like LifeBook."
Prepared by Claude, 2026-07-16. Facts verified against vendor documentation July 2026.
Purpose: a secure, honest staging deployment so one explicitly consented participant (Olya) can experience LifeBook naturally — without building architecture we will discard.

---

## 1. The comparison, against LifeBook's actual requirements

| Requirement | Vercel | Netlify | Minimal AWS |
|---|---|---|---|
| Next.js 16 server routes/runtime | Native (Vercel makes Next.js; 16.x fully supported) | Good via OpenNext adapter (16 deploys zero-config; adapter maturing) | Amplify does NOT support Next 16 SSR yet; SST/OpenNext or plain `next start` on Lightsail works |
| PostgreSQL + our role-split migrations | Any external PG; Supabase **ca-central-1** pairs cleanly (custom roles confirmed; Supavisor pooling for serverless) | Same | RDS ca-central-1 (~$13–15/mo) — full control, most plumbing |
| Server-side sessions + doorway tokens | Works (standard cookies/route handlers) | Works | Works |
| Secret handling | Encrypted per-environment env vars, write-only "sensitive" mode | Comparable | SSM/Secrets Manager — more setup |
| Private / invitation-only access | Password protection costs **$150/mo add-on** — instead: our own staging-gate middleware (free, portable, ours) | Password protection needs Pro; `_headers` basic-auth hack | nginx basic-auth free (Lightsail) |
| Temporary email delivery | Resend (free 3k/mo, needs a verified sender domain, US-hosted) or Postmark (free 100/mo) or SES **ca-central-1** (Canadian residency, most friction) | Same | SES ca-central-1 natural fit |
| **Canadian residency** | **Functions in Montréal (`yul1`, since Jan 2026) + database in Supabase ca-central-1 = compute AND Book at rest in Canada** | Functions region for Canada unconfirmed — likely not | Everything ca-central-1 — strongest story, highest effort |
| Complexity / cost | Lowest; Pro $20/mo (Hobby is non-commercial by ToS) + Supabase free tier + email free tier | Low-moderate; $19/mo; adapter risk on a 5-day-old framework version | Highest; $5–15/mo; days not hours |
| Migration path | Nothing proprietary in our code (plain Next + `pg` + SQL migrations); later move = repoint DNS + env | Same | Already the likely destination |

## 2. Recommendation

**Vercel Pro (functions pinned to Montréal `yul1`) + Supabase Postgres in ca-central-1 + our own staging-gate middleware + Postmark free tier for doorway emails.**

Why: it is the smallest correct thing. Next 16 runs on its maker's platform with zero adapter risk; the Book rests in Canada **and** — thanks to `yul1` — is *processed* in Canada, which exceeds Decision 019's minimum posture; the database roles and migrations run unchanged (Supabase allows our two-role privilege split); everything in our repo stays portable, so the eventual production decision (possibly full AWS ca-central-1, possibly not) inherits rather than restarts. Postmark over Resend for the email seat: its free 100/month needs no new domain purchase decision today if we use an existing domain Tracy controls for DKIM — and doorway emails are the only mail LifeBook sends.

**Access control is our own doorway, not a vendor paywall:** a tiny middleware gate — visiting with a one-time staging key (a link Tracy sends) sets a cookie; without it, the deployment shows nothing. Consistent with how LifeBook already thinks, free instead of $150/month, and it comes with us when we leave.

## 3. Named compromises (each disclosed in the consent language)

1. **Inference still crosses the border** — the Companion's provider calls leave Canada under Anthropic's development terms (no training on API data by default; ~7-day standard retention; not ZDR). Within Decision 019's approved posture, but staging runs on dev-grade terms, not the signed production contract.
2. **Doorway emails route through a US processor** (Postmark/Resend) — only the email address and the login link, never memories. SES ca-central-1 is the upgrade if this compromise is unacceptable.
3. **Supabase's platform roles** technically retain administrative access to the database (as would any managed provider); our app-role privilege split still holds internally.
4. **No automated tests yet** (Gate 1, condition 3) — mitigated below by scope control, the deletion drill, and a founding-team smoke test on staging before Olya's URL exists.
5. Vercel Pro is $20/month; Supabase and Postmark free tiers suffice at this scale.

## 4. Can Olya's test ethically occur before all seven Gate-1 conditions are complete?

**Not as an "outside Storykeeper." Yes — as a controlled founding-team participant.** The honest reading of Gate 1: the seven conditions gate the *uncontrolled* widening — people who arrive with only the product's own promises to protect them. Olya can precede that only if the protections the product doesn't yet offer *in software* are provided *in person*, explicitly:

- **Informed consent BEFORE the URL** (draft below) — given outside the product, so the experience itself stays minimally framed, as you intended. Consent is the price of minimal framing, not its enemy — it just lives in the invitation, not the threshold.
- **Deletion must exist before her first word** — not self-serve (condition 4 stands for the wider circle), but real: a rehearsed `keeper --forget` command that removes a named Storykeeper's everything, audited, demonstrated on a test identity *before* she begins. Her right to vanish cannot be a promise; it must be a tested capability.
- **Export on request** — a manual, complete extract (SQL → readable document) promised in consent and honoured within days.
- **Provider terms disclosed, not hidden** — she is told her words transiently cross the border under no-training dev terms.
- **She remains "founding team" in status** until the seven conditions close: named in the repo as a Founding Storykeeper / cultural advisor, able to reach Tracy directly, entitled to ask anything about where her words live.

One more thing she must be told, because we already know it: **she is already *in* this database** — as Olga, in Tracy's Book, from Tracy's conversations. Her own Book is entirely separate (verified: a Storykeeper's context spans only their own claimed Books), but the person deserves to know the system already holds another's memories of her — that is observation #28 asking to be practiced, not just logged.

**Verdict: the test may proceed under the controlled-participant frame once the deletion drill has passed and she has consented. It may NOT proceed as a bare "here's a URL" to someone outside the protections above.**

## 5. Consent language (draft for Tracy to personalize — plain words, no legalese)

*(Rewritten in LifeBook's voice at the Director's direction — the facts identical, the posture changed from briefing to welcoming.)*

> Olya — before I invite you into LifeBook, there's something important I want you to know. LifeBook is built on trust, and I want you to understand exactly what you're saying yes to.
>
> LifeBook remembers. That is its whole purpose. Everything you tell it is kept permanently, word for word, in a database in Canada — not summaries of your words, your words.
>
> To speak with you, it shares what you say with an AI service (Anthropic) outside Canada. Under our current agreement your words are never used for training and are kept only briefly. A stronger contract comes before LifeBook ever opens to the public — you are far earlier than that.
>
> The sign-in email you'd receive travels through an American email service. Only the email — never your memories.
>
> You can change your mind at any time, about all of it. Say the word, and everything you've entrusted disappears — permanently, and provably; we built that ability and rehearsed it before inviting you. You can also ask, any time, for a complete copy of everything you've told it.
>
> I run the system, which means I could technically reach the database it lives in. The application itself is built so that nothing reads your words without an audited reason — but you deserve the honest version, and that's it.
>
> And one thing you should know before anything else: because Iryna and I already use LifeBook, it holds our memories that mention you. Those live in our space — yours would be only yours, and we cannot see it. But that felt like something you should know before you decide, not after.
>
> If all of that feels right, I'll send you a doorway. Use it however feels natural — there are no instructions, and that's deliberate. Afterwards, just tell me the story of your experience: what felt right, what felt wrong, what surprised you. In any language you like.

## 6. Staged deployment plan (upon approval — nothing executed yet)

- **Stage 0 — Decisions & accounts (Tracy):** approve this plan; Vercel Pro account; Supabase project in ca-central-1; Postmark account + DKIM on a domain you control (which domain?); confirm consent wording; confirm Olya's status as Founding Storykeeper (controlled participant).
- **Stage 1 — Build items (Claude, ~a day):** email transport adapter (Postmark) behind the existing honest-refusal seam; staging-gate middleware; `keeper --forget <storykeeper-id>` with dry-run and audit; small `export` script (SQL → readable document) so the consent promise is backed by a tested command.
- **Stage 2 — Database:** create Supabase project; run migrations 0001–0003; create `lifebook_app` / `lifebook_keeper` roles with the privilege split; **re-run the UPDATE-refusal proof against Supabase** — the Week 1 demo, repeated on real infrastructure.
- **Stage 3 — Deploy:** connect the private GitHub repo to Vercel; pin functions to `yul1`; set secrets (staging Anthropic key — a NEW key, not the dev one; DB URLs; Postmark token; staging gate key). Deploy.
- **Stage 4 — Drills:** deletion drill on a test identity (create → converse → `--forget` → verify audit + absence); export drill; doorway email end-to-end to Tracy's own phone.
- **Stage 5 — Founding-team smoke test:** Tracy (and Iryna if willing) walk the full trust loop on staging from personal devices — threshold, memory, doorway, homecoming.
- **Stage 6 — Olya:** consent conversation → her personal staging-gate link → she uses LifeBook naturally.
- **Stage 6½ — Reflection (Director's addition):** before any discussion of improvements — let Olya simply tell the story of her experience; ask no leading questions; record observations before discussing solutions; compare her observations against the Foundation; only then decide whether anything enters the Observation Log. *Our methodology deserves the same discipline we ask of the Companion.*

## 7. What this staging is NOT

Not production. Not the residency end-state (though it happens to satisfy it). Not the audition (the provisional provider still speaks; the audition still decides). Not the wider circle — conditions 1–7 of TECHNICAL_REVIEW.md still gate that, unchanged.
