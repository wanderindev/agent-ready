# Phase 1 — Area 4c Report: Swallowed-exceptions sweep across `backend/app/services/`

**Date:** 2026-05-19
**Duration:** ~1.5 hours (catalogue structure + sweep + synthesis + filing + report)
**Scope:** Every module in `backend/app/services/` (20 files). Strict scope; one router site (`orders.py:495-498`) catalogued as a scope-edge handoff from Area 2.

---

## Executive summary

The services layer has a vocabulary of about 9 distinct swallow shapes spread across 22 explicit `except` blocks plus 16 caller-side wrapper-bool-discard sites. The dominant signal: most "swallows" aren't independent decisions — they're caller-side instances of wrapper-contract problems already captured in #67 (Composio), #70 (notifications), #74 (mailing_list). Filing per-site would have produced ~16 issues that go obsolete after the 4 wrapper-contract PRs land.

The catalogue (posted as a comment on #8) is the primary deliverable. Three sites warranted standalone issues — all moderate, all agent-friendly:

- **#83**: `image_storage.generate_thumbnail` silent Pillow failure (caller can't recover)
- **#84**: `orders.py:495-498` `except Exception: pass` masking PayPal cancel failures (router; scope-edge)
- **#85**: `media_scoring` broad catch aborts entire scoring run on transient errors

No stop-the-line incidents. No new critical-severity findings. The sweep validated the 4a hypothesis that the wrapper-contract cluster is the highest-leverage fix and that systematic per-line filing would mostly be noise.

The most encouraging observation: the codebase already contains the **right pattern** in three places (`wikimedia.py:260` narrow `(KeyError, IndexError)` catch, `loc.py:323` / `wikimedia.py:296,319` disciplined `stats["errors"].append`, `research.py:164` / `edu_research.py:166` narrow `(JSONDecodeError, IndexError)` LLM fallback). Whoever lands #76 (unified LLM wrapper) and #67 (Composio contract) has a clear style to standardize on.

---

## By the numbers

| Metric | Count |
|---|---|
| Modules surveyed | 20 (all of `backend/app/services/`) |
| Explicit `except` blocks in `services/` | 22 |
| Wrapper-induced caller-side sites (bool/None discarded) | 16 |
| Independent active-masking sites | 2 |
| Independent intentional-fallback sites | 18 |
| Uncaught LLM `messages.create(...)` sites | 18 across 8 modules |
| Issues filed | 3 (all `code-quality:moderate`, all `agent-friendly`) |
| Stop-the-line incidents | 0 |

---

## Catalogue location reference

The full catalogue is posted as a single structured comment on issue #8:
https://github.com/wanderindev/panama-in-context/issues/8

Sections in the comment:
- §1 — Wrapper-induced sites (20 entries; resolve via #67/#70/#74)
- §2 — Independent active-masking (3 entries; all filed)
- §3 — Independent intentional fallback (17 entries; rationale recorded)
- §4 — Pattern variants observed (aggregate counts by shape)
- §5 — Inverse pattern: uncaught propagation in LLM modules

---

## What's filed separately and why

| # | Title | Why standalone | Severity | Agent-friendly |
|---|---|---|---|---|
| #83 | `image_storage.generate_thumbnail` silently swallows Pillow failures | Caller has no error trail; UI shows broken thumb with no actionable signal | moderate | yes |
| #84 | `orders.py:495-498` `except Exception: pass` masking PayPal cancel failures | Textbook bad pattern; produces uncorrelated PayPal payments if the assumed-cancel actually failed | moderate | yes |
| #85 | `media_scoring` broad `except Exception` aborts entire scoring run | Transient API errors should skip the batch, not terminate; broadest catch in LLM modules | moderate | yes |

**On #84 (the scope edge):** the swallow lives in a router, not a service. Area 2 explicitly handed it to 4c via its "Newly observed" section. Filing here during 4c with a scope note rather than punting back to Area 2's backlog — the catalogue is the right home for this pattern even when the line is in `api/`.

Everything else — 16 wrapper-induced sites, 17 intentional fallbacks, 18 uncaught LLM calls — lives in the #8 catalogue. Per-site filings would have been ~30+ issues, most of which would be obsolete after #67/#70/#74/#76 land.

---

## Methodological notes

### What turned out to be common (calibration data for 4b)

- **The `stats["errors"].append` pattern is the most observability-friendly** local idiom in this codebase. Three sites (LOC + Wikimedia crawl orchestrators) use it. It's better than `logger.error` alone because the failure is surfaced in the function's return value, not just in async log-tailing. 4b should consider standardizing crawler-orchestrator patterns around this shape.
- **Narrow exception catches do exist** — `wikimedia.py:260` does `except (KeyError, IndexError)`; `research.py:164` and `edu_research.py:166` do `except (json.JSONDecodeError, IndexError)`. These are the templates the broader catches should be migrated toward.
- **The wrapper-bool cluster is by far the largest single pattern**: 16 caller-side discards across 3 modules. This validates 4a's framing that fixing #67/#74 is higher-leverage than per-site filing.

### What turned out to be rarer than expected

- **Bare `except: pass` is rare.** I found exactly one in the entire `backend/app/`: `orders.py:495-498`. The rest of the codebase at least logs. That's better than expected — the textbook bad pattern is not pervasive.
- **`media_scoring`'s broad catch is the only instance** of "broad catch around an entire complex block" in the LLM modules. The other LLM modules either don't catch at all (propagate uncaught — the §5 pattern) or use narrow catches. So #85's fix is a one-site standardization, not a systematic problem.
- **No security-implications from any swallow.** The Sentry `send_default_pii=True` concern raised in 4a remains separate. The catalogue surfaced no swallows around credential rotation, auth, or PII handling.

### What was easier than expected

- **The 4a "newly observed for 4c" section was load-bearing.** Roughly 70% of the wrapper-induced sites I catalogued were already named at the line level in the 4a report. The sweep mostly verified rather than discovered. Without the 4a groundwork this would have been a 3-4 hour audit, not 1.5 hours.

### What was harder than expected

- **§3 calls (intentional vs masking) required judgment per row.** "Likely intentional" sites that *also* have a broad catch (`except Exception` rather than narrow) are uncomfortable to leave alone — they're defensible today, but they'd mask any future bug in the same code path. I erred on the side of "catalogue with rationale" rather than "file" because the rationale was reasonable in each case. A different reviewer might file 5-8 of these as nice-to-have narrowings.

### Calibration data for 4b (domain pipelines)

4b will read the same modules I read in Pass 2, but for orchestration concerns, not exception handling. Items 4c surfaced that 4b should pick up:

- **`edu_material_generation._parse_outline_response`** (line 25-57) is a good example of defensive parsing without `try/except`. The function falls back gracefully on every malformed input. 4b might want this pattern surfaced when discussing #77 (defensive LLM parsing).
- **`media_scoring.py:117` was the broadest catch found.** 4b should note that #85 (filed) and #76 (unified wrapper) interact: if #76 lands first, #85's fix becomes "use the wrapper" rather than the inline narrowing sketched in #85.
- **The 3 disciplined `stats["errors"].append` sites** all live in crawler orchestrators. 4b should consider whether the edu pipeline (`generate_edu_materials`, `generate_edu_slides`) would benefit from a similar pattern — today these throw on first failure, abandoning any prior grade-band progress.
- **5 separate `anthropic.Anthropic()` instances confirmed.** 4a counted these architecturally; 4c counted them at the same level of granularity. 4b should resolve whether #76 unifies them or whether they get a service-by-service wrapper.

---

## Newly observed — for other audit areas

### For 4b (domain pipelines)

- **`media_scoring.py:117` interacts with #85 and #76** — if #76 lands first, #85's fix surface shrinks to "use the wrapper." If #85 lands first, #76's wrapper inherits the narrowed catch as its baseline. Sequence matters.
- **`wikimedia.py:198-202` per-batch failures aren't appended to `stats["errors"]`** — minor inconsistency with the per-seed/per-category disciplined pattern in the same module. Not severe enough to file standalone; would be a 2-line fix during whatever 4b ticket covers the Wikimedia orchestrator.
- **`paypal.verify_webhook_signature:227-228` fall-open** is already filed as #32; mentioning here so 4b doesn't re-discover.
- **`request_followup_email` is still un-called** (4a's deferred item). The missing scheduler is 4b territory; this sweep confirmed no service-layer caller exists.
- **`edu_material_generation._parse_outline_response` is a defensive-parsing template** (no `try/except`; structural fallbacks). Could be the reference pattern in #77's fix.

### For 4d / wherever the Sentry hardening lands

- **`wikimedia.py:408-410` is the only silent-no-log swallow** in `services/` (outside `orders.py:495-498` which is the router). If a Sentry-classify-every-except sweep ever happens (the original framing of #8), this site needs at minimum a `logger.debug` so the choice is intentional rather than missing.
- **The 3 disciplined `stats["errors"].append` sites** still don't reach Sentry — the errors are returned in the response dict but the admin endpoint doesn't capture them to Sentry. Worth surfacing as a follow-up when admin observability is revisited.

### Cross-area / for whenever

- **The wrapper-bool-discard cluster is now fully mapped.** When #67 + #74 land, an agent or human can drive the 16 caller-side updates from the §1 list mechanically (each one is "stop discarding the return; either propagate failure to the response or capture to Sentry"). The catalogue serves as the agent prompt for that batch.

---

## What surprised me

1. **The `stats["errors"].append` pattern existed in the codebase already.** I went in expecting the crawler modules to be the worst-shaped (per 4a's #73), but they have the *most* disciplined error-surfacing pattern in the codebase. The crawler orchestrators do better than the FastAPI request handlers at structured failure reporting. The broken thing about LOC/Wikimedia is the inline-blocking-in-an-HTTP-handler shape, not the per-call failure handling.

2. **Exactly one bare `except: pass` exists in all of `backend/app/`.** I expected several. The codebase is structurally better than 4a's framing suggested — there's one bad apple (`orders.py:495-498`), not a systemic culture of swallowing.

3. **`educator_service.py`'s `_send_*_email` helpers log the bool result.** They go beyond `mailing_list.py`'s helpers by recording "sent" vs "FAILED" with the email address. That's better visibility than `mailing_list.py` has. Yet the callers in the same file *still* discard the bool. Local discipline + caller-side discard is a worse failure mode than uniform broken-ness, because it suggests someone noticed the problem partway and only fixed half of it.

4. **The narrow-catch templates already exist.** `wikimedia.py:260` (narrow `(KeyError, IndexError)`) and `research.py:164` (narrow `(JSONDecodeError, IndexError)`) are exactly the pattern #76/#77 should standardize. The structural fix isn't inventing a new pattern — it's promoting an existing local idiom to a codebase convention.

5. **The catalogue's value is in the rationale column, not the row count.** I expected 30+ rows to feel overwhelming. In fact, once §1 is grouped under #67/#74 and §3's "intentional fallback" rationale is recorded, the catalogue compresses to 3 standalone issues + 4 wrapper-contract clusters + a handful of style observations. The information density is high but the noise is low. This format should be reusable for future systematic sweeps.

6. **No PayPal swallows in `services/paypal.py` itself.** All PayPal `try/except` activity in this codebase is in routers (`orders.py:495`, plus the already-filed #34 idempotency concerns). The service module itself is clean — it propagates HTTP errors via `raise_for_status()`. Surprising given how thick the integration is.

---

## Process notes for the next area (4b)

- **The wrapper-bool §1 list in #8 is the prompt for the post-#67-and-#74 cleanup.** When those two land, the 16 caller-side fixes can be driven from the catalogue. Worth flagging in #67/#74 as the follow-up scope.
- **The disciplined `stats["errors"]` pattern should be referenced** when 4b discusses orchestration patterns. It's already the convention; 4b should consider whether to extend it to the edu pipeline.
- **The narrow-catch templates** (`wikimedia:260`, `research:164`) are the references when 4b touches #77. Cite them rather than inventing a new defensive-parse style.
- **Sequencing matters for #85 vs #76**: prefer #76 first, then #85's fix becomes "wrap it" rather than "narrow inline."
- **Don't re-audit the LLM modules' exception shape.** The catalogue's §5 has them all. 4b's value-add on LLM modules is prompt orchestration, max_tokens choices, thinking budgets — not exception handling.