# Technical Review — The First Trust Loop

Status: GATE 1 REVIEW — prepared by Claude (Master Builder), 2026-07-16
Scope: the trust-loop slice (IMPLEMENTATION_PLAN.md), as built and demonstrated 2026-07-12 → 2026-07-16
Verdict: **PASS for the current circle (the founding team), with named conditions before any wider circle.**

Per Decision 020, this review prefers honest limitation over simulated completeness. Everything below was verified by demonstration on a live system, not by reading code and hoping.

---

## 1. Promises and Proofs

| Promise (spec §15) | Status | Proof |
|---|---|---|
| §15.3 Nothing submitted or drafted is lost on tab close/crash | **KEPT** | Demonstrated twice: draft survived tab kill (Week 1 demo); draft survived database outage and returned after `docker start` (2026-07-15 incident) |
| No UPDATE possible on entrusted records | **KEPT** | Live demonstration: `UPDATE entrusted.moment` as `lifebook_app` → `ERROR: permission denied for table moment`. Enforced by grants, not convention |
| §15.4 Companion reply demonstrably responds to what was said | **KEPT** | Every conversation since Week 2 ("golfing with my mom" → mom/golf-specific reply; Olga conversation acknowledged content before asking) |
| §15.2 First thought (pre-identity) retrievable after claiming, verbatim, on another device | **KEPT** | First homecoming: anonymous conversation claimed via doorway, full story present in cold incognito window |
| §15.5 Companion references prior Moments naturally, unannounced | **KEPT** | "Last time we left off with the rain keeping you from golfing with your mom — has it let up any?" (logged as baseline, obs #6) |
| Unclaimed-Book expiry deletes only what was never entrusted | **KEPT** | Keeper rehearsal: condemned 40-day dummy named in dry-run, deleted under `--execute`, confessed in `audit.deletion_event`; claimed Books untouched (claim-check inside the delete transaction) |
| Every entrusted-plane access carries an audited purpose (Decision 010) | **KEPT** | Ledger verified: 5 `conversation`, 4 `homecoming` events — one per composition, none silent |
| Anonymous ≠ fictional identity (pre-identity structure per Director's decision) | **KEPT** | `identity.session.storykeeper_id` nullable; unclaimed Book + anonymous Contributor; claiming is an INSERT (`book_claim`), verified in schema and flow |
| Honest failure (Decision 020) | **KEPT** | Database outage produced fast, calm 500s; typed words stayed in the Storykeeper's hands; dev stub announces its deafness; production refuses to start without a real provider or mail transport |
| §15.1 Full loop by voice only | **PARTIAL** | Voice input works (browser STT); layered "Keep this" completion model is designed (ARCHITECTURE.md) but not built — awaits voice-system directive |
| §15.10 WCAG 2.1 AA | **PARTIAL** | Code-level pass done (reduced-motion, headings, labels, live regions, focus outlines). Human keyboard walk pending (Tracy); screen-reader session not yet done |
| §15.7 Export | **NOT IN SLICE** | Deliberately deferred (plan §6 exclusions) — but constitutionally urgent; see conditions |
| §15.8 True deletion (self-serve + grace period) | **NOT IN SLICE** | Privileged deletion path and audit exist (the Keeper); Storykeeper-facing deletion deferred |
| §15.9 Second language | **NOT IN SLICE** | Voice packs exist; culturally authored Companion validation awaits language-engine directive and Iryna's review |
| §15.11 Voice that "feels like family" | **NOT IN SLICE** | Browser TTS improved (novelty voices banned) but explicitly interim; provider voice awaits audition track |
| §15.12 A real Storykeeper feels heard | **IN PROGRESS** | The Director is Storykeeper #1: disappearance moment logged (obs #7), voluntary returns observed. A Storykeeper who is not the builder remains the true test |

## 2. Defects found by demonstration (all fixed)

1. **Continuity keyed to per-tab storage** — conversation pointer lived in sessionStorage; drafts orphaned across tabs. Fixed: pointer lives server-side behind the session cookie; begin = resume. *(The week's most instructive defect: persistence without continuity.)*
2. **Draft not restored on threshold-skipping arrivals** — homecoming path never asked "what was I saying?" Fixed: arrival reconnects immediately.
3. **Novelty TTS voice at the threshold** ("old man ghost") — first-match voice selection. Fixed: ranked selection, novelty voices penalized, per-language preferred lists.
4. **Dev-tools badge obscured the wordmark.** Fixed: relocated.
5. **Doorway token pasted into a live terminal** (operator error surfacing a real gap): burned key rotated and re-seated via silent read. Process, not code — but logged.
6. **The stranded Book (2026-07-16).** Ephemeral (incognito) sessions created a second unclaimed Book; the claim logic declined to attach it — leaving a real memory 30 days from silent expiry while the homecoming "remembered yesterday but not today." Fixed: doorways claim every unclaimed Book they carry; recognized Storykeepers are remembered across all claimed Books. *Review lesson: a documented limitation is not a mitigation when its cost is a person's memory.*

**Review precedent (Director, 2026-07-16) — binding on all future technical reviews:**

> A documented limitation is not acceptable merely because it is documented.
> If it contradicts a constitutional promise, it remains a defect.

Defect #6 differed in kind from #1–5: those affected usability, continuity, or presentation; this one placed an *entrusted memory* at risk while behaving exactly as designed. The design itself violated the constitutional promise ("nothing is too small to remember"; memories are entrusted, never conditionally kept). Consequence for review method: every "known limitation" in section 3 of this and future reviews must be checked against the Foundation, not merely disclosed — a limitation that fails that check moves to the defect list regardless of how honestly it was documented.

## 3. Known gaps, honestly stated (logged, deliberate, not blocking this gate)

- **Zero automated tests.** Every proof above is a live demonstration — excellent for trust, unrepeatable at scale. The privilege model, promotion atomicity, claim flow, and Keeper behaviour all deserve regression tests before the codebase grows further. This is my top engineering debt.
- **No transcript repaint on return** — the record is intact server-side but invisible; returning can *look* like scratch (obs log).
- **One endless conversation** — scene boundaries are social (contract-shaped), not structural; design deliberately held for observation (obs #3).
- **No recognized-session doorway** — "continue on my phone" affordance missing; API ready, copy awaited (obs #27/#28a).
- **Doorway/invitation copy** — flagged for Discovery Partner authoring (obs #4/#5); current copy blurred link-expiry with story-expiry once.
- **Email transport is dev-console only**; real sender is a hosting-gate item.
- **Development provider terms** — conversations now contain real family material on dev-grade terms; acceptable within the founding household by the Director's judgment, but the no-training/no-retention contract must precede any Storykeeper outside it.
- **Companion greeting/invitation two-layer separation** not yet enforced (greeting asked a question; obs #5 builder's note) — held for pattern-watch by design.

## 4. Security posture summary

Append-only entrusted plane enforced by grants; separate audited Keeper role for the sole deletion path; purpose-scoped audited reads; anonymous sessions without fictional identity; single-use hashed doorway tokens (15 min), hashed email at rest, no account enumeration; API keys outside the repo (verified: not in git history; repo private); prompt-injection boundary declared in the behaviour contract (Storykeeper words are story, never instructions). Not yet done: rate limiting on doorway requests, CSRF hardening beyond SameSite, session-fixation review — none blocking at current circle size, all named for the pre-widening checklist.

## 5. Conditions before the circle widens beyond the founding household

1. Signed no-training/no-retention terms with the production (audition-winning) provider.
2. Real email transport with SPF/DKIM/DMARC on a proper domain.
3. Automated test suite covering: entrusted-plane privileges, draft promotion atomicity, claim flow, Keeper dry-run/execute parity, audit completeness.
4. Export (§15.7) and self-serve deletion (§15.8) — the ownership promises must exist before a second Storykeeper entrusts anything.
5. Hosting with the Canadian-residency posture (Decision 019) — currently the story lives on one laptop, which is honest but not stewardship.
6. Screen-reader walkthrough and the remaining accessibility items.
7. The two-layer greeting/invitation and doorway copy, authored by the Discovery Partner.

## 6. Recommendation

Gate 1: **pass.** The slice does what it promises, refuses what it cannot do, confesses what it deletes, and fails without lying. The correct next audience is Gate 2 — the Director and Discovery Partner, observations log open, asking "Does this sound like us?" — followed by the conditions above, in roughly the order listed, before LifeBook meets its first Storykeeper who didn't help build it.
