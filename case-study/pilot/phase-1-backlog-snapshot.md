# Phase 1 — GitHub Backlog Snapshot

**Date:** 2026-05-20
**Purpose:** Accurate current-state snapshot of the filed issue backlog, as the input for the Phase 1 synthesis report. Read-only aggregation — no interpretation, no fix-ordering, no recommendations.

> **Count flag (read first).** The kickoff brief expected "~99 filed issues, ~95 open / ~5 closed." Actual: **111 filed issues, 110 open, 1 closed.** The direction is benign — *fewer* closed than expected, not more, so nothing closed unexpectedly. Two specifics the synthesis should note up front:
> - **Only #31 is closed.** Phase 1 was a *filing* phase (the audit plan: "It does not fix things, with the two stop-the-line exceptions"). PR #49 (Area 3 stop-the-line) shipped a code fix but had **no tracking issue**, so it closes nothing in the issue list.
> - The brief lists **#21 as an inline fix** ("#21, #31, #49 PR"). #21 is **open** — `code-quality:critical`, `agent-friendly`. It was filed, never closed, and the Area 1 report names it as the hard prerequisite for #3. See §8.

---

## 1. Headline counts

| Metric | Value |
|---|---|
| Total filed issues | **111** (#3–#122, excluding PR numbers) |
| Open | **110** |
| Closed | **1** |
| Closed — `COMPLETED` | 1 (#31) |
| Closed — `NOT_PLANNED` (duplicate / won't-fix) | 0 |

**The one closed issue:** #31 — closed `COMPLETED` on 2026-05-19 by `wanderindev`, referenced by commit `4842e3c`.

**Non-issue numbers in the #1–#124 range** (PRs and audit-report PRs, not issues): #1, #2, #20, #30, #48, #49, #66, #82, #86, #98, #105, #123, #124. #49 is the Area 3 stop-the-line PR; #20/#30/#48/#66/#82/#86/#98/#105/#123/#124 are the Phase-0/Part-A and per-area report PRs; #1/#2 predate the audit. The audit reports' "closed inline / fixed via PR" claims were cross-checked against GitHub: no audit report falsely claims a closure (Area 1 "Nine issues filed… No stop-the-line"; Area 3's stop-the-line was PR #49 with no issue). The only mismatch is the kickoff brief's own characterization of #21 (see §8).

---

## 2. Open issues by severity

| Severity label | Open count |
|---|---|
| `code-quality:critical` | **15** |
| `code-quality:moderate` | **64** |
| `code-quality:nice-to-have` | **31** |
| (no severity label) | 0 |
| `bug` / `enhancement` | 0 — no such labels exist in the repo |

Every open issue carries **exactly one** `code-quality:*` severity label. The backlog is uniformly `code-quality`-labelled; there are no `bug`/`enhancement` issues.

**The 15 open criticals:** #3, #5 (Phase 0 infra) · #21 (Area 1) · #32, #33, #34 (Area 2 — PayPal webhook) · #50, #51, #52, #53 (Area 3 — educator access) · #67, #68, #69 (Area 4a — services) · #91 (Area 4b-1 — edu regen) · #99 (Area 4b-2 — series-sections).

---

## 3. Open issues by agent-friendly status

**42 of 110 open issues (38%) are `agent-friendly`.**

| | agent-friendly | not agent-friendly | total |
|---|---|---|---|
| critical | **2** | 13 | 15 |
| moderate | **21** | 43 | 64 |
| nice-to-have | **19** | 12 | 31 |
| **total** | **42** | 68 | 110 |

**The 2 agent-friendly criticals:** #21 (add missing model imports to `alembic/env.py`) and #69 (`image_storage.download_image` enforces size cap after full read). Both are narrow, well-scoped.

**Agent-friendly moderates (21):** #11, #12, #17, #35, #55, #56, #60, #61, #77, #83, #84, #85, #106, #107, #108, #110, #117, #118, #119, #120, #121.

**Agent-friendly nice-to-haves (19):** #28, #44, #46, #62, #63, #64, #65, #79, #80, #89, #93, #103, #104, #109, #113, #114, #115, #116, #122.

---

## 4. Open issues by audit area / origin

Issue→area mapping verified against the audit reports (each area's "Issues filed" section). Ranges are contiguous; the gaps between ranges are PR numbers.

| Area | Issue range | Open | crit / mod / nice | agent-friendly | Source report |
|---|---|---|---|---|---|
| **Phase 0 backlog** | #3–#19 | 17 | 2 / 11 / 4 | 3 | `phase-0-report.md` (Part A intake) |
| **Area 1 — data layer** | #21–#29 | 9 | 1 / 5 / 3 | 2 | `phase-1-area-1-report.md` |
| **Area 2 — payments/bookings** | #31–#47 | 16 (+1 closed) | 3 / 9 / 4 | 3 | `phase-1-area-2-report.md` |
| **Area 3 — auth / educator gate** | #50–#65 | 16 | 4 / 8 / 4 | 8 | `phase-1-area-3-report.md` |
| **Area 4a — cross-cutting services** | #67–#81 | 15 | 3 / 8 / 4 | 4 | `phase-1-area-4a-report.md` |
| **Area 4c — swallowed-exceptions sweep** | #83–#85 | 3 | 0 / 3 / 0 | 3 | `phase-1-area-4c-report.md` |
| **Area 4b-1 — edu pipeline** | #87–#97 | 11 | 1 / 7 / 3 | 2 | `phase-1-area-4b-1-report.md` |
| **Area 4b-2 — article pipeline** | #99–#104 | 6 | 1 / 2 / 3 | 2 | `phase-1-area-4b-2-report.md` |
| **Area 5 — frontend public site** | #106–#116 | 11 | 0 / 6 / 5 | 9 | `phase-1-area-5-report.md` |
| **Area 6 — frontend admin CMS** | #117–#122 | 6 | 0 / 5 / 1 | 6 | `phase-1-area-6-report.md` |
| **Totals** | | **110** | **15 / 64 / 31** | **42** | |

No open issue falls outside a single audit area — every issue traces cleanly to one filing session. (Several issues are *cross-area in subject matter* — #18, #57, #111 — but each was filed once, in the area listed; later areas commented rather than re-filing. See §6.)

---

## 5. Closed issues — what got resolved and how

| # | Title | How it closed | When / by |
|---|---|---|---|
| #31 | HTML injection in notification emails: customer-controlled fields rendered unescaped in admin-bound HTML | `COMPLETED` — closed by a referenced commit (`4842e3c`) | 2026-05-19, `wanderindev` |

That is the entire closed set. For completeness, the audit's other "fix" actions that did **not** produce a closed issue:

- **PR #49** (Area 3 stop-the-line) — added authentication to the `admin.py` and `media_library.py` routers that shipped with none. Shipped as a PR; the vulnerability had no pre-existing tracking issue, so no issue closed. The follow-up finding #54 (fragile manual-`validate_admin_token` pattern) remains open.
- Phase 0 inline work (CI rebuild, gitleaks, Dockerfiles, cert-watcher) predates the issue backlog and is recorded in `phase-0-report.md`, not as issues.

---

## 6. The "shared foundation" clusters

Multi-issue work that the fix-ordering bridge sections identified as "clusters, not individuals." All issues below are **open** unless noted.

### A. LLM foundation — #76 cluster
- **Core:** #76 (no unified Anthropic wrapper), #77 (inconsistent LLM-response parsing), #78 (no token/budget observability), #68 (no SDK timeouts — shared with cluster B).
- **Downstream LLM-quality cleanup** the 4b-2 bridge says #76 reshapes: #92 (edu `grade_bands` cost cap), #93 (edu outline `max_tokens` truncation), #101 (suggestion `max_tokens` budget), #102 (article research-condensation step), #103 (`research.py`/`edu_research.py` duplication).
- 4b-2 framing: "#76 reshapes edu's #93/#92/#77 and article's #101/#102/#103/#77."

### B. Composio contract — #67 cluster
- **Core:** #67 (`composio_client.send_email` returns True on Gmail-side failure), #68 (no timeout).
- **Caller-side:** #70 (`notifications.py` misuses the bool return), #74 (`mailing_list` discards the bool), #59 (educator email-dispatch swallowed), #37 (payment-flow dispatch swallowed).
- 4a framing: "the broken-wrapper-bool cluster — #67 ↔ #37 ↔ #59 ↔ #70 ↔ #74." 4c adds that when #67+#74 land, "16 caller-side updates" can be driven mechanically; the 4c catalogue issues #83/#84/#85 are siblings.

### C. Educator access — #50 + #52 + #60 (backend + frontend)
- #50 (public-media API has no server-side gate), #52 (forgeable unsigned access token), #60 (frontend grants access from stale `localStorage`).
- Broader Area 3 educator surface in the same blast radius: #51 (unauthenticated unsubscribe), #53 (verify-code brute-force), #58 (enumeration oracle), #61 (no auth-failure audit log), #62/#63/#64/#65 (educator-service hygiene). Area 5 confirmed the frontend gate is cosmetic; the load-bearing fix is #50 (backend).

### D. Research-upload hardening — #87/#88/#89 + #100
- #87 (title-substring match instead of explicit ID), #88 (silent overwrite, no status reset), #89 (no upload size cap) — edu; #100 (blog `upload_research` mirrors the same three). 4b-2: "one work item across two modules."

### E. Order-confirmation / analytics — #36 + #47 + #112
- #36 (OrderConfirmation never fetches the order — needs a backend `OrderResponse` schema change), #47 (Meta Pixel `Purchase` value `0`, depends on #36), #112 (analytics fire in all environments). Area 5 bridge.

### F. Token lifecycle — #43 + #57
- #43 (customer magic-link tokens in URL query strings), #57 (admin tokens in URL — confirmed comprehensively across ~50 `admin.js` call sites in Area 6). Area 6 also recorded a logout-doesn't-revoke gap on the #57 thread.

### G. HTML sanitization — #111 (one fix, multiple consumers)
- #111 — `content_html` rendered unsanitized; one backend sanitizer in `markdown_to_html` discharges three consumers (public `ArticleContent`, admin `EduResearchEditor`, admin `EduMaterialEditor`). Same family as the closed #31 and the open #80 (raw f-string HTML).

### H. Code-splitting — #18 (spans Area 5 + Area 6)
- #18 — the 2.65 MB single-chunk bundle. The only issue spanning two audit areas; Area 6 commented to assign the admin track ownership rather than filing a duplicate.

### I. Migration baseline — #3 cluster
- #3 (generate initial alembic migration) is gated by #21 (env.py model imports — autogenerate is wrong until fixed) and #23 (resolve column drift before stamping), and pairs with #4 (drop orphan tables/enums).

### J. Model hygiene — #22/#23/#24/#25/#26/#29 + #95/#96
- Area 1 schema-shape findings plus edu schema findings #95/#96. 4b-1 proposed sequencing #95/#96 with #22/#24/#29/#4 as one models mini-batch.

### K. PayPal webhook — #32/#33/#34 (+#41/#44)
- Three criticals plus moderates, all in the PayPal webhook path. Area 2 established the PayPal integration is unexercised dead code — this cluster is **dormant**, not live.

---

## 7. Wave-1 candidates from the four bridge sections

Per the cumulative "Toward a global fix ordering" bridges (4b-2, Area 5, Area 6), global Wave 1 has four concurrent tracks. Current status of every named issue:

| Track | Issues | Status |
|---|---|---|
| **edu critical** | #97 → #91 → #90 | all **open** |
| **article critical** | #99 (+ articles 39/40 prod data cleanup) | #99 **open**; the 39/40 cleanup is a data fix, not an issue |
| **LLM foundation** | #76 (+ #68, #77, #78) | all **open** |
| **frontend safety-net** | #7, #106, #110 | all **open** |

All 13 Wave-1 issue numbers are open. Nothing in Wave 1 has been started or closed.

---

## 8. Synthesis-prep observations

Things noticed while compiling this snapshot. Flagged, not analyzed — the synthesis report does the interpretation.

1. **Phase 1 is a pure filing phase.** 110 of 111 issues open; the lone close (#31) was a discrete HTML-injection fix. This matches the audit plan ("does not fix things"). The synthesis should not expect prior progress to have changed the backlog — it is essentially all still in front of Phase 2.

2. **The brief's "#21 inline fix" is wrong — #21 is open and critical.** It was filed (Area 1), never closed. The Area 1 report names it the hard prerequisite for #3 (initial migration): autogenerate produces wrong output until `env.py` imports all 23 models. So **#3 is still blocked** — its prerequisite is unmet. The migration-baseline cluster (§6-I) cannot start at #3.

3. **The filed-issue total is 111, not the brief's "99."** Twelve more issues exist than the brief assumed. The #1–#124 range minus 13 PR numbers = 111 issues. Worth reconciling before the synthesis quotes a total.

4. **Severity is moderate-heavy.** 15 critical (14%) / 64 moderate (58%) / 31 nice-to-have (28%). The synthesis's global ordering is mostly a moderate-tier sequencing problem; criticals are a small, enumerable set.

5. **Three of the 15 criticals are dormant.** #32/#33/#34 (PayPal webhook) are critical-by-severity but Area 2 established the PayPal integration is unexercised dead code — they cannot fire today. By contrast #99 is the one critical with *confirmed live production corruption* (articles 39/40 carry doubled nav blocks). The synthesis may want to distinguish "live critical" from "dormant critical" when ordering — a dormant critical and a live moderate are not obviously co-ranked.

6. **Agent-friendliness is sharply area-skewed.** Frontend areas are near-fully agent-friendly: Area 5 (9/11) and Area 6 (6/6). Backend/infra is not: Phase 0 (3/17), Area 4a (4/15), Area 4b-1 (2/11). This confirms the bridge sections' "backend narrow-and-deep / frontend wide-and-shallow" framing and points at the frontend (28 issues, ~94% agent-friendly) as the Phase 2 autonomous-agent track.

7. **Only 2 agent-friendly criticals exist** — #21 and #69. Both are narrow and well-scoped. If Phase 2 wants a high-value low-risk opener, these two are the only critical-tier candidates an agent could plausibly take unaided.

8. **Labeling is clean.** Every open issue has exactly one severity label; zero unlabelled; no `bug`/`enhancement` labels in the repo at all. No re-classification was needed and none was done. The one structural oddity is that "agent-friendly" is a flat label with no gradation — borderline cases (the reports flagged #51, #54 as "borderline") are not distinguishable in the label data.

9. **The silent-failure / swallowed-error theme is bigger than any one area names it.** #8 is literally the Phase 0 issue "sweep services for swallowed exceptions"; its concrete instances are scattered as #37, #59, #67, #70, #74, #83, #84, #85 across Areas 2/3/4a/4c — and #117 (Area 6) is the same pattern in the admin frontend. The synthesis may want to treat #8 as an umbrella over a ~9-issue theme rather than a standalone item. This overlaps but is not identical to the Area 6 report's "partial-correction debt" observation.

10. **A few issues are genuinely cross-area but filed once.** #18 (code-split) spans Areas 5+6; #57 and #111 were confirmed in later areas via comments rather than re-filing. This snapshot assigns each to its filing area for the §4 table, but the synthesis's cluster view (§6) is the more accurate lens for those three.
