# LifeBook Discovery Operations Model
**Version:** 0.2  
**Status:** Revised per Discovery Partner corrections — 2026-07-25  
**Produced:** 2026-07-25  
**Produced by:** Discovery Partner + Claude (architecture session)  
**Relates to:** GOVERNANCE_MODELS.md, SCHEMA_INVENTORY.md, PRE_MIGRATION_CLOSURE.md  
**Does NOT modify:** Any existing migration or schema specification

---

## Purpose

This document describes the Discovery Registry as an operational subsystem distinct from the LifeBook product schema. It defines what the Discovery Registry governs, what data it holds, how it interacts with the LifeBook participant experience, and — critically — where it intentionally does not intersect with the LifeBook schema.

The Discovery Registry is not a LifeBook feature. It is a governed operational record of the company's research, early access, and Founding Round activities. Its relationship to the LifeBook product schema is asymmetric by design: the registry informs the product; it does not populate it.

---

## 1. What Is the Discovery Program?

The Discovery Program has two overlapping dimensions:

**Dimension A — Customer Discovery**

Structured conversations with potential Storekeepers, family members, and others who may benefit from LifeBook. These sessions are conducted by trained interviewers using the Interview Guide and are governed by the Interviewer Covenant and Participant Guide. They generate research insight, not product content.

**Dimension B — Founding Round Enrollment**

A cohort of early participants who are invited to be among the first Storekeepers. Founding Round participants receive access under the conditions described in the Financial Stewardship Package and the Participant Guide. Their consent is formal, documented, and jurisdiction-specific.

Both dimensions produce operational records that require governance. The Discovery Registry is the system that holds those records.

---

## 2. What the Discovery Registry Governs

The Discovery Registry is an operational system that tracks:

### 2.1 Participant Identity Records

Each person who has participated in a Discovery session or enrolled in the Founding Round has a Participant Identity Record. This record contains:

| Field | Notes |
|---|---|
| `participant_id` | Internal UUID; not shared outside the registry |
| `full_name` | As provided at time of enrollment |
| `preferred_name` | If different from legal name; as provided |
| `contact_email` | Primary contact |
| `contact_phone` | Optional |
| `preferred_language` | Language used in session |
| `jurisdiction_code` | For PIPEDA and equivalent compliance |
| `date_of_first_contact` | |
| `referral_source` | How they came to LifeBook |
| `enrollment_type` | `discovery_only` / `founding_round` / `founding_round_plus_discovery` |
| `current_status` | `active` / `withdrawn` / `deceased` / `transitioned_to_storykeeper` |
| `notes` | Internal operational notes; not shared with participant |

**Important:** Participant Identity Records are governed by PIPEDA and applicable provincial legislation. They are not Person entity records in the LifeBook schema. A Participant Identity Record exists only to manage the operational relationship with the participant. It carries no claims, predicates, or narrative content.

### 2.2 Session Records

Each Discovery session generates a Session Record:

| Field | Notes |
|---|---|
| `session_id` | Internal UUID |
| `participant_id` | FK to Participant Identity Record |
| `session_date` | |
| `interviewer_id` | Which interviewer conducted the session |
| `session_type` | `introductory` / `discovery` / `founding_round_enrollment` / `follow_up` |
| `session_language` | BCP 47 language tag |
| `session_medium` | `in_person` / `video` / `phone` / `written` |
| `duration_minutes` | Approximate |
| `interview_guide_version` | Version of the Interview Guide used |
| `notes_summary` | High-level summary of themes discussed; not verbatim transcript |
| `verbatim_transcript_exists` | Boolean; if true, a transcript record exists in the Media Record table (§2.6) |
| `recording_exists` | Boolean; if true, a recording record exists in the Media Record table (§2.6) |
| `off_record_segment_occurred` | Boolean; records only that an off-the-record segment took place, not its content. Off-the-record content must not be retained in any form |
| `off_record_segment_count` | Integer; nullable; number of discrete off-record segments, for audit completeness only |
| `consent_documented` | Boolean |
| `follow_up_status` | Enum: `none_required` / `pending` / `in_progress` / `completed` / `overdue` |
| `follow_up_due_date` | Nullable date |
| `follow_up_completed_date` | Nullable date |
| `follow_up_assigned_to` | Which team member owns the follow-up; nullable |

**Off-the-record policy:** When a participant indicates they are speaking off the record, the content of that segment must not be retained in any form — not in notes, summaries, transcripts, or recordings. Only the fact that an off-the-record segment occurred, and the number of such segments, may be logged. Interviewers must be explicitly trained on this distinction. Any system that automatically transcribes sessions must be paused or reviewed for off-the-record segments before retention.

**Important:** Session notes and summaries remain in the Discovery Registry. They do not become Narrative, Claim, or any other content record in the LifeBook schema, regardless of the content of the conversation.

### 2.3 Consent Records

Each formal consent event generates a Consent Record:

| Field | Notes |
|---|---|
| `consent_id` | Internal UUID |
| `participant_id` | FK to Participant Identity Record |
| `consent_type` | `discovery_participation` / `founding_round_enrollment` / `verbatim_transcript` / `research_use` / `contact_permission` |
| `jurisdiction_code` | Applicable jurisdiction at time of consent |
| `consent_date` | |
| `consent_method` | `written` / `verbal_documented` / `digital_signature` |
| `document_version` | Version of the governing document (Participant Guide version, etc.) |
| `scope` | What the participant consented to; structured or free text |
| `declined_items` | What the participant explicitly declined |
| `withdrawn_date` | Nullable; populated when consent is withdrawn |
| `interviewer_id` | Who documented the consent event |

Consent Records are the legal basis for any use of information collected in Discovery sessions. They govern the Discovery Registry. They do not govern LifeBook product data — separate consent infrastructure in the LifeBook product schema governs that relationship.

### 2.4 Founding Round Records

Founding Round participants have an additional record:

| Field | Notes |
|---|---|
| `founding_round_id` | Internal UUID |
| `participant_id` | FK to Participant Identity Record |
| `enrollment_date` | |
| `cohort` | Which Founding Round cohort (FR-01, FR-02, etc.) |
| `commitment_type` | Per the Financial Stewardship Package |
| `access_granted_date` | When product access was activated |
| `access_expires_date` | Nullable |
| `steward_assigned` | Which LifeBook team member is the participant's point of contact |
| `status` | `enrolled` / `active` / `paused` / `completed` / `withdrawn` |

### 2.5 Media Records

Each recording or transcript associated with a Discovery session has a Media Record:

| Field | Notes |
|---|---|
| `media_id` | Internal UUID |
| `session_id` | FK to Session Record |
| `participant_id` | FK to Participant Identity Record |
| `media_type` | Enum: `recording_audio` / `recording_video` / `transcript_verbatim` / `transcript_summary` |
| `source_platform` | Enum: `zoom` / `in_person_recorder` / `phone` / `manual_upload` / `other` |
| `original_filename` | As received from the source platform |
| `storage_reference` | Opaque reference to the file in the governed storage system; not a public URL |
| `access_classification` | Enum: `interviewer_only` / `team_restricted` / `team_unrestricted`; default `interviewer_only` |
| `upload_verified` | Boolean; true when upload integrity has been confirmed |
| `upload_verified_by` | Team member who verified the upload; nullable if not yet verified |
| `upload_verified_at` | Timestamp; nullable |
| `source_deletion_required` | Boolean; true when the source platform copy must be deleted after verified upload |
| `source_deletion_confirmed` | Boolean; false until deletion is verified |
| `source_deletion_confirmed_by` | Team member who confirmed deletion |
| `source_deletion_confirmed_at` | Timestamp; nullable |
| `retention_review_date` | Date when this media record is next scheduled for a retention review |
| `retention_decision` | Enum: `retain` / `delete` / `pending_review`; default `pending_review` |
| `retention_decided_by` | Team member who made the retention decision; nullable |
| `retention_decided_at` | Timestamp; nullable |
| `deleted_at` | Timestamp; populated when the file is deleted from storage |
| `deleted_by` | Team member who confirmed deletion from storage |
| `created_at` | Timestamp |
| `notes` | Internal operational notes |

**Zoom-source deletion policy:** When a session is recorded via Zoom, the LifeBook-governed copy must be verified as uploaded and intact before the Zoom cloud copy is deleted. `source_deletion_confirmed` must be set to true, with a named confirming team member and timestamp, before the Zoom deletion is treated as complete. Zoom recordings must not be retained on the Zoom platform indefinitely — deletion after verified upload is the required practice, not a preference.

**Access classification:** Media records default to `interviewer_only`. Elevation to `team_restricted` or `team_unrestricted` requires an explicit decision by the team lead and must be logged in the access classification change history (see §2.6.1).

#### 2.5.1 Media Access Classification Change Log

Every change to a Media Record's `access_classification` must be logged:

| Field | Notes |
|---|---|
| `log_id` | Internal UUID |
| `media_id` | FK to Media Record |
| `previous_classification` | Prior access_classification value |
| `new_classification` | New access_classification value |
| `changed_by` | Team member making the change |
| `changed_at` | Timestamp |
| `reason` | Required free text justification |

### 2.6 Erasure and Withdrawal Records

When a participant requests withdrawal or erasure:

| Field | Notes |
|---|---|
| `erasure_id` | Internal UUID |
| `participant_id` | FK to Participant Identity Record |
| `request_date` | |
| `request_type` | `withdrawal_from_program` / `erasure_of_discovery_data` / `both` |
| `jurisdiction_code` | Applicable jurisdiction |
| `completion_date` | When erasure was completed |
| `completed_by` | Which team member executed |
| `items_erased` | Structured record of what was deleted |
| `items_retained` | What was retained and under what lawful basis |
| `notes` | Internal record |

---

## 3. What the Discovery Registry Explicitly Does Not Govern

The following are outside the Discovery Registry's scope and must not be added to it:

- Content of LifeBook conversations (Moments, Narratives, Claims)
- LifeBook account credentials or authentication records
- Storykeeper relationship graph (Entity anchors, Relationships)
- LifeBook governance records (AuthorityAssignment, ApprovalRecord, etc.)
- Any record covered by the LifeBook product schema

---

## 4. Intersections with the LifeBook Schema

The Discovery Registry intersects the LifeBook schema in exactly four places. All four are one-directional: the Discovery Registry triggers a transition into the LifeBook schema; the LifeBook schema never writes back to the Discovery Registry.

### 4.1 Access Grant — Founding Round → LifeBook Account

When a Founding Round participant's access is activated (`access_granted_date` is set on the Founding Round Record), an account is created in LifeBook. This account creation is an operational act performed by the LifeBook team. It does not automatically port any information from the Discovery Registry.

**What crosses the boundary:**
- The participant's email address (to create auth.users record)
- Their preferred language (to set default language in LifeBook)
- Their access level (Founding Round status may grant specific permissions)

**What does not cross the boundary:**
- Discovery session notes or summaries
- Consent records (a separate, new consent interaction occurs within LifeBook)
- Any personal information beyond what is needed for account creation

### 4.2 Storykeeper Transition Status

When a Founding Round participant's `current_status` is updated to `transitioned_to_storykeeper`, the Discovery Registry records this transition by date. No automatic data transfer occurs.

The LifeBook account associated with this participant begins as an empty LifeBook. The participant's history in the Discovery program is not pre-populated into their LifeBook. The Storykeeper's LifeBook content begins with their first conversation on the LifeBook platform.

**This is a deliberate architectural separation.** The Storykeeper's LifeBook is theirs, beginning from their first interaction with the product. Discovery program materials — even materials the participant themselves shared during sessions — are not automatically their LifeBook content.

### 4.3 Founding Round Access Permissions — One-Time Provisioning

When a Founding Round participant's access is activated (`access_granted_date` is set on the Founding Round Record), the provisioning process creates a **LifeBook-native entitlement record** within the LifeBook product schema. This record encodes the participant's access level, cohort tier, and any associated pricing terms as first-class LifeBook data.

After provisioning, the LifeBook access layer reads only the LifeBook-native entitlement record. It does not query the Discovery Registry at runtime. The Discovery Registry is never a dependency of a live application request.

**What the entitlement record contains:**
- The LifeBook account UUID (from auth.users)
- Access tier (corresponding to the Founding Round cohort)
- Effective dates
- Feature flags or entitlements specific to this cohort
- A provenance note recording that this entitlement was provisioned from a Founding Round enrollment

**What the entitlement record does not contain:**
- Discovery session content
- Consent records
- Interview notes or media references
- Any personally identifying information beyond the account UUID

**Implications:** A bug in the LifeBook entitlement system is a LifeBook product bug — it is debugged and corrected within the LifeBook schema, not by querying the Discovery Registry. The Discovery Registry remains the authoritative record of enrollment history; the LifeBook entitlement record is the operational record of access rights.

### 4.4 Jurisdiction Reference

The `jurisdiction_code` on the Participant Identity Record is used during LifeBook account creation to pre-select the applicable jurisdiction for the new LifeBook. This is a hint, not a binding assignment — the participant may update their LifeBook jurisdiction independently during onboarding.

---

## 5. Intentional Non-Intersections

The following are explicitly prohibited. Each represents a potential architectural temptation that must be resisted.

### 5.1 Discovery notes are not Narratives

Interview notes, session summaries, and off-the-record insights collected during Discovery sessions are research records. They may reveal things about a participant's life. They may contain moving stories, important names, and meaningful events.

They are not LifeBook Narratives. They are not Claim candidates. They must not be imported into the LifeBook schema — not even if the participant later becomes a Storykeeper and would benefit from having that content available.

**Why:** The consent given for Discovery participation does not extend to LifeBook content use. A participant who consented to be interviewed for research did not consent to have that interview become part of their permanent LifeBook record. Any use of Discovery session content as LifeBook content requires a new, explicit consent event within the LifeBook product.

If a Storykeeper wants to bring earlier memories into LifeBook, they do so through the normal conversation interface, starting fresh. They may, if they choose, reference their Discovery session and add that content deliberately. That is their decision — not the system's.

### 5.2 Participant Identity Records are not Person entities

A Participant Identity Record in the Discovery Registry is not a Person entity in the LifeBook schema. Creating a Founding Round account does not automatically create a Person entity record for the participant in their LifeBook.

A Person entity record is created in LifeBook only when the Storykeeper creates one — typically as a reference to themselves or to someone else in the context of a memory or relationship. The mechanics of LifeBook identity (Entity anchor, PersonName, etc.) apply only once the Storykeeper has begun building their LifeBook.

### 5.3 Discovery erasure is independent of LifeBook erasure

When a participant requests erasure from the Discovery Registry, that erasure applies to the Discovery Registry only. If the same person has a LifeBook account, erasure from the LifeBook product is a separate request handled under the LifeBook product's PIPEDA compliance process.

Conversely, if a Storykeeper requests deletion of their LifeBook account, that request does not cascade to the Discovery Registry. If they participated in the Discovery program, those records remain governed by the Discovery Registry's retention and erasure rules.

This separation ensures that neither system's erasure process inadvertently violates the other's legal obligations or erases records that are necessary for compliance documentation.

### 5.4 Research insights are not LifeBook schema signals

Anonymized, aggregated insights derived from Discovery sessions may inform product development, feature prioritization, or operational decisions. They may not be used as inputs to any LifeBook schema signal — not to the Atmosphere Engine, not to the AI Context Broker, not to the Governance Engine.

Product insights derived from research remain at the product level. They inform how the product is designed. They do not flow into individual Storekeepers' governed records.

---

## 6. Technology and Storage

The Discovery Registry is a governed operational system, not a product feature. It requires a structured database from day one — not a spreadsheet.

**Why a structured database, not a spreadsheet:**
The Discovery Registry tracks participants' sensitive personal information, session media, consent records, and erasure obligations. These records carry legal retention and access requirements. A spreadsheet cannot enforce access controls at the row or field level, cannot produce a reliable audit log, cannot manage FK relationships between participants and sessions, and creates unacceptable data integrity risk as the participant population grows. Spreadsheets may be used as operational views or exports (e.g., a summary export for a weekly team meeting) but the authoritative registry must be a structured system.

**Required at launch:**
- A structured database with row-level access controls and audit logging (Supabase, PostgreSQL, or equivalent)
- File storage for media records (recordings, transcripts) with access-controlled references — not public URLs (see §2.5)
- Version history and change logging on all records
- Backup and point-in-time recovery
- Access provisioned per team member, not shared via a single account

**Spreadsheet use:**
A spreadsheet is an acceptable export format for specific operational views (e.g., follow-up tracking, session scheduling). The export must be generated from the structured registry, treated as a read-only operational view, and not used to update the registry. Data entered into a spreadsheet that is not reflected back into the structured registry is not in the Discovery Registry.

**Media storage:**
All recordings and transcripts must be stored in access-controlled file storage with references tracked in the Media Record table (§2.5). File storage must be separate from the team's general file-sharing environment (e.g., not in a general-access Google Drive folder). Zoom cloud recordings must be downloaded to governed storage and deleted from Zoom after verified upload (see §2.5).

**Privacy obligations — jurisdiction review required:**
The specific privacy obligations applicable to the Discovery Registry depend on the jurisdiction of each participant and the jurisdiction of the LifeBook team's operations. The following are working assumptions that must be reviewed by qualified privacy counsel before the Discovery Program launches in any jurisdiction:

- Participant data may be subject to PIPEDA (Canada), applicable provincial privacy legislation, or equivalent legislation in other jurisdictions
- Cross-border processing of participant data may require explicit consent or specific safeguards depending on the jurisdictions involved
- Timelines for responding to participant access, correction, and erasure requests are jurisdiction-specific
- Retention periods for Discovery Registry data are jurisdiction-specific and use-case-specific

A jurisdiction-specific privacy review must be completed, documented, and signed off before any participant is enrolled in the Discovery Program in that jurisdiction. The review must cover: what data is collected, where it is stored, how long it is retained, who has access, and what rights participants have. This review is an operational prerequisite, not a post-launch correction.

---

## 7. Open Questions Requiring Resolution

1. **Retention period:** How long are Session Records and associated Media Records retained after a participant withdraws or declines to enroll? The applicable privacy legislation defines "as long as necessary for the purpose collected." Define specific retention periods for each record type in the privacy review (§6) before launch. Different record types may have different retention periods (e.g., Consent Records may need to be retained longer than Session Notes for compliance evidence purposes).

2. **Verbatim transcript policy:** Under what conditions is a verbatim transcript captured? Who has access? What is the retention period? The Interview Guide notes off-the-record insight capture; the verbatim transcript question requires a separate policy.

3. **Interviewer access controls:** Which team members may access Discovery Registry records? Interviewers should have access to their own sessions; should they have access to all sessions? Define access tiers.

4. **Research use boundaries:** The Participant Guide mentions that anonymized insights may inform product development. Define more precisely what constitutes "anonymized" for this purpose, and who approves research use of Discovery session content.

5. **Founding Round cohort design:** Are Founding Round cohorts sequential (FR-01, FR-02) or thematic? What determines cohort membership? This affects the `cohort` field on the Founding Round Record and the content of the LifeBook-native entitlement record (§4.3).

6. **Transition experience:** When a Founding Round participant transitions to a full Storykeeper, what is their first experience in the product? The empty LifeBook approach is architecturally correct; the product experience of "beginning" when you've already spoken with LifeBook interviewers needs to be designed with care.

7. **Structured registry platform selection:** Which structured database platform will serve as the Discovery Registry? The platform must support row-level access controls, audit logging, file storage references, and backup. Selection must happen before any participant data is collected.

8. **Media storage platform:** Which file storage platform will hold recordings and transcripts? Must support access-controlled retrieval (not public URLs), audit logging, and deletion confirmation. Selection must happen before the first recorded Discovery session.

---

## 8. Relationship to Existing Foundation Documents

| Document | Relationship |
|---|---|
| `GOVERNANCE_MODELS.md` | Governs the LifeBook product schema; Discovery Registry has its own, simpler governance. The principles of subject authority and consent granularity in GOVERNANCE_MODELS.md inform the Discovery Registry's consent design but do not bind it |
| `PRE_MIGRATION_CLOSURE.md` | Discovery Registry is not part of the migration gate. It is an operational tool that exists before and alongside the product schema |
| `CONTENT_LAYER.md` | Discovery session content must not become Content Layer records without explicit new consent (§5.1 above) |
| `AI_CONTEXT_BROKER.md` | Discovery session content must not be used as Context Broker inputs. The Content Layer governs what the AI may access; Discovery data is outside that boundary by design |
| `ARCHITECTURE_FREEZE_V1.md` | The Discovery Registry is not governed by the Architecture Freeze. It is an operational tool. However, the principles in §3 (particularly P2 — Claims own facts) inform the non-intersection rules in §5 above |

---

*The Discovery Registry is governed by operational practice, not by the LifeBook product schema. This document is its governing specification. Updates require Discovery Partner review.*
