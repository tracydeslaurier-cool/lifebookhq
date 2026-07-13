# AI Provider Evaluation

Status: EVALUATION — recommendation at end; decision is the Director's (Week 0 gate)
Last updated: 2026-07-12
Research basis: current provider documentation and reporting as of July 2026; sources listed at end. Items marked ⚠ are single-source and must be verified before contract signature.

---

## Conflict-of-Interest Disclosure

This evaluation was prepared by Claude, an Anthropic model — one of the candidates. The Discovery Partner (ChatGPT) is an OpenAI product — another candidate. **Both AI team members have a structural conflict of interest in this decision.** Mitigations: every factual claim below is sourced; the evaluation criteria were fixed before scoring; the recommendation is a *process* (a judged bake-off) rather than a self-serving verdict; and final judgment on conversational quality belongs to human ears — Tracy's and, for Ukrainian, Iryna's.

---

## What LifeBook Actually Needs

Weighted by the Foundation, not by benchmark fashion:

1. **Conversational warmth and restraint** — a model that can follow the Conversation Principles (one question, acknowledge first, no performance). This is the product.
2. **Ukrainian at native emotional quality** — Decision 004 makes this a launch gate, not a nice-to-have.
3. **No-training / minimal-retention terms** — Decision 010 and the spec's privacy promises are contractual requirements.
4. **Canadian data options** — proposed residency posture (spec §17).
5. **Low time-to-first-token** — calm breaks at ~3 seconds of dead air (plan §6).
6. **Structured output + tool calling** — Contextus and the Interpretation Engine will live on these.
7. **Long context** — Contextus v0 loads the whole Book; a life is long.
8. **Decade-long survivability** — of the company *and* of our exit path from it.

---

## Candidates

Realistic candidates: **Anthropic (Claude)**, **OpenAI (GPT)**, **Google (Gemini)**, **Cohere (Command)**, **Mistral** — each reachable directly or via a cloud (AWS Bedrock, Azure AI Foundry, Google Vertex AI), which changes the residency and contract picture materially. Self-hosted open weights are treated as a hedge, not a candidate: running frontier-quality inference ourselves is beyond a team of one human and two AIs.

---

## Comparison

### Conversation quality
All three majors (Claude, GPT, Gemini) are capable of the register LifeBook needs; the differences at the frontier are stylistic, and *style is our whole product*. Claude's reputation centers on instruction-following restraint and natural warmth; GPT on breadth and polish; Gemini on speed and multilingual reach. Cohere's Command A+ is enterprise-RAG-oriented — strong at retrieval work, less evidenced for intimate conversation. Mistral likewise. **No benchmark measures "would Grandma feel heard"; only the bake-off can.**

### Latency (time-to-first-token, streamed)
Fastest tiers: Gemini Flash and Claude Haiku 4.5 (~600ms class). All five stream over SSE. All meet the 3-second first-words bar with mid-tier models; frontier-tier models are tighter but workable with streaming. Latency favors running the conversational voice on a mid-tier model — which also fits the budget.

### Multilingual — Ukrainian specifically
The best *evidenced* Ukrainian performers are OpenAI (GPT-4o topped ZNO-Eval, the Ukrainian standardized-exam benchmark) and Google (the Ukrainian-LLM community chose Gemini as its Ukrainian-quality judge, citing cultural nuance). Claude is close behind but less specifically evidenced. Cohere's Command A+ lists 48 languages without prominently claiming Ukrainian ⚠; Mistral is EU-language-focused, Ukrainian unverified. **All public benchmarks predate the mid-2026 model generation — this is precisely why Iryna's ear outranks every citation here.**

### Structured output & tool calling
OpenAI's Structured Outputs is the maturity leader (<0.1% schema failure, native Zod support). Claude and Gemini both ship schema-enforced structured output (~99.7–99.8% compliance) and mature tool calling. Mistral passes third-party compliance tests; Cohere is solid but with a smaller ecosystem. None of the five is disqualifying.

### Long context
Claude (Opus/Sonnet lines) and OpenAI: 1M tokens. Gemini 3.1 Pro: ~1M. Mistral Large 3: 256K. Cohere: 128–256K. All exceed slice-1 needs by orders of magnitude; the 1M-class options future-proof Contextus longest.

### Retention / privacy / training terms
- **Anthropic:** no training on API data by default; standard API log retention 7 days (shortest default in the set); ZDR for approved customers. ⚠ One report claims ZDR does not extend to its newest frontier model tier — verify directly before signing.
- **OpenAI:** no training on API data by default; up to 30-day abuse retention; ZDR by approval on eligible endpoints. Note: litigation-related retention orders complicated deletion guarantees for some *non*-ZDR traffic in 2025 — an object lesson in why we contract for ZDR rather than trust defaults.
- **Google:** paid tier (Gemini API/Vertex): no training, Cloud DPA governs; the free tier trains and must never touch LifeBook.
- **Mistral:** paid API no-training; ZDR only on their top plan, stateless endpoints only.
- **Cohere:** ⚠ the only candidate that may use SaaS API data for training *by default* (opt-out exists; enterprise contracts override). Fixable by contract, but the default posture is telling.

### Canadian data options — the decisive constraint
This is where the picture inverts. Frontier models reach Canada slowly:

- **AWS Bedrock (ca-central-1):** hosts Anthropic, Cohere, Mistral, Meta models. Nuance: much Canadian "availability" is cross-region inference — **data at rest (logs, configurations) stays in Canada while inference may execute in US/global regions.** True in-region inference covers a smaller, older subset. Bedrock contractually never trains on customer data.
- **Azure (Canada East/Central):** genuine in-region inference for regionally deployed OpenAI models — but the newest models lag Canada by generations (GPT-4o-class reliable; GPT-5-family partial ⚠).
- **Google Vertex (Montréal):** in-region processing guaranteed when available, but current-gen Gemini in Montréal is the thinnest of the three ⚠.
- **Cohere:** the only *sovereign* Canadian story — Toronto-based, and the June 2026 Bell partnership builds fully domestic training-and-hosting infrastructure. But it goes live late 2026 at the earliest, and Cohere's conversational and Ukrainian evidence is the weakest of the set.
- **Anthropic/OpenAI direct APIs:** no Canada-specific residency.

**The honest decision this forces:** strict in-Canada *inference* means using year-old models and accepting whichever provider has the best Canadian region that quarter. The alternative posture: **the Book lives in Canada; the conversation may transiently cross the border.** Entrusted data at rest stays in Canadian infrastructure permanently; inference happens wherever the best model is, under signed zero/short-retention and no-training terms, disclosed to the Storykeeper in plain language. PIPEDA permits cross-border processing with transparency and comparable protection. This posture is a Director's decision — it shapes the privacy disclosure itself.

### Pricing (per 1M tokens, July 2026; verify at signature)
| Provider | Conversational tier | Frontier tier |
|---|---|---|
| Anthropic | Sonnet 5: $2/$10 intro (then $3/$15); Haiku 4.5: $1/$5 | Opus 4.8: $5/$25 |
| OpenAI | GPT-5.4: $2.50/$15; Luna: $1/$6 ⚠ | GPT-5.5: $5/$30 |
| Google | Gemini 3.5 Flash: $1.50/$9 | Gemini 3.1 Pro: $2/$12 |
| Cohere | Command A: $2.50/$10 | Command A+ (TBD ⚠) |
| Mistral | Medium 3: $1/$3 | Large 3: $2/$6 |

At V1 scale (one to a handful of Storykeepers, whole-Book context), cost is noise — under $100/month at any realistic usage with prompt caching. Pricing matters at year three, not week three; all majors cluster closely enough that it should not drive the decision.

### SDK maturity
Anthropic, OpenAI, Google: mature official TypeScript SDKs — full marks. Mistral and Cohere: official TS SDKs, smaller ecosystems. Bedrock/Azure/Vertex SDKs are mature but add a cloud-SDK layer.

### Likelihood of decade-long support
Google (Alphabet): existential risk nil; API churn risk real. Anthropic and OpenAI: both near-trillion-dollar valuations, both IPO-bound in 2026, both with deep enterprise adoption — strong survival signals, though both burn cash. Cohere (merged with Aleph Alpha, ~$20B combined) and Mistral (~$20B): viable but an order of magnitude smaller; both hedge by shipping open weights, which means their models can outlive them. **The real decade strategy is not picking the survivor — it is AD-4:** every provider sits behind our seam, the entrusted plane stores nothing provider-shaped, and the understanding plane is regenerable. LifeBook survives any vendor's death by re-running interpretation. We already built for this.

### Ability to support Discoverus, Contextus, Acceptus over time
The faculties need, respectively: nuanced emotional/associative reasoning (Discoverus); reliable structured extraction, tool use, and retrieval over long context (Contextus); and register-faithful composition across formats (Acceptus). All three majors can serve all three faculties today, and nothing prevents **different faculties using different providers later** — the directive already permits it, and Contextus's structured-output workload may eventually suit a different model than Acceptus's voice. The architecture makes this a config change, not a redesign.

---

## Recommendation

**1. Adopt the residency posture first (Director's decision):** the Book at rest in Canada, inference transiently cross-border under signed no-training/zero-or-short-retention terms, disclosed plainly. Strict in-Canada inference would chain LifeBook's voice to whatever lags into Canadian regions — a worse product for a marginal, and honestly disclosable, difference.

**2. Run a two-week judged bake-off, not a paper decision, among three finalists:**
- **Claude (Sonnet-class) via AWS Bedrock** — data at rest in ca-central-1; strongest default retention posture (7-day); reputation for conversational restraint.
- **GPT (5.4-class) via Azure or direct with ZDR** — best-evidenced Ukrainian; gold-standard structured outputs.
- **Gemini (3.5 Flash / 3.1 Pro) via Vertex** — community-recognized Ukrainian strength; best latency; most-certain decade of corporate existence.

Identical harness for all three: the real system prompt built from CONVERSATION_PRINCIPLES.md, the same ten synthetic conversations (English and Ukrainian, including a grief scenario and a rambling multi-topic memory), judged blind by Tracy and Iryna on: felt heard / one question / no performance / Ukrainian that reads as *written for me*. Latency measured alongside. Cohere and Mistral are excluded as finalists on conversational-evidence and Ukrainian grounds respectively, but **Cohere is named the designated re-evaluation candidate for 2027** when the Bell sovereign fabric is live — if Canadian-soil inference becomes a requirement, that door is open.

**3. My provisional ranking, conflict disclosed, human judgment supreme:** on the criteria weighted by the Foundation — warmth-and-restraint first, Ukrainian second, retention terms third — I would expect Claude and GPT to contend for the voice, with the Ukrainian test likely decisive between them, and Gemini the strong fallback holding the latency and longevity cards. I am an Anthropic model recommending a process in which an OpenAI model could win on the strength of a Ukrainian grandmother's ear. That is the correct shape for this decision.

**4. Whatever wins, sign for:** no training on our data, zero or minimal retention in writing, and confirmation of the ⚠ items above before signature.

---

## Implementation Note (Director, 2026-07-12)

**The Companion audition harness is permanent infrastructure — not scaffolding for an initial provider selection.** The audition will be repeated whenever a materially better capability may exist, ensuring LifeBook continuously evaluates suppliers while preserving the Companion's identity (Decision 018) and the Storykeeper experience. Cohere remains the designated Canadian re-evaluation candidate within this periodic supplier review.

**Status of this evaluation's recommendations:** residency posture — APPROVED (Decision 019: entrusted data resides in Canada; inference may cross the border only under the approved privacy posture). Finalists — APPROVED: OpenAI, Anthropic, Google Gemini. Audition protocol: see `audition/PROTOCOL.md`.

## Development Provider (PROVISIONAL — Director, 2026-07-13)

**Anthropic Claude is the development provider**, chosen for engineering efficiency only: the Master Builder knows this API natively, which means fewer adapter defects and a faster Week 2. Conflict of interest disclosed at selection (Claude is an Anthropic model). This choice carries **no weight toward production** — the blind Companion audition determines the production provider, and switching is a configuration exercise (`COMPANION_PROVIDER` / `COMPANION_MODEL` environment variables behind the `CompanionProvider` seam). Development uses synthetic and team-only memories until production terms are signed with the audition winner.

---

## Sources

Pricing: platform.claude.com/docs pricing; developers.openai.com/api/docs/pricing; ai.google.dev/gemini-api/docs/pricing; mistral.ai/pricing; cohere.com/pricing.
Retention/training: platform.claude.com API data-retention docs and Anthropic ZDR help articles; openai.com/enterprise-privacy and OpenAI "your data" docs; OpenAI response-to-NYT-data-demands; Google Cloud Gemini data-governance docs; Cohere enterprise-data-commitments; Mistral privacy/data-controls docs.
Canada: AWS Bedrock model-region compatibility docs and AWS Canada cross-region-inference blog; Microsoft Learn Q&A on Canada-region model availability and in-region inference; Google Vertex AI locations and data-residency docs; CBC and Bloomberg on the Bell–Cohere sovereign infrastructure deal (June 18, 2026); SAP–Cohere Canada sovereign-AI announcement (Feb 2026).
Ukrainian: ZNO-Eval (arXiv 2501.06715); INSAIT MamayLM notes on Gemini's Ukrainian; UNLP Ukrainian benchmarks (arXiv 2411.14647).
Latency/structured output: aimultiple and benchlm latency benchmarks; Requesty cross-provider structured-output compliance tests.
Stability: Anthropic Series H announcement; CNBC (May 2026) on Anthropic/OpenAI valuations; Sacra/futuresearch OpenAI revenue analyses; TechCrunch on Cohere valuation; Cohere Command A+ announcement; Mistral funding announcements; CNBC on Mistral/ASML.
