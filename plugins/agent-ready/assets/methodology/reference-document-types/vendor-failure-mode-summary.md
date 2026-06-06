# Vendor failure-mode summary

## Purpose

For each external vendor the audited area touches, a clear, single-page-per-vendor statement of: what the wrapper does on vendor success, what it does on vendor error, what it does on vendor timeout, whether the failure is visible upstream (raises) or invisible (swallowed/None/False), and what would happen system-wide if the vendor were down for an hour. The summary becomes a load-bearing reference for any future incident or reliability conversation — when a vendor outage actually happens, the audit's prior characterization of "what fails how" is more useful than re-deriving it under pressure.

The summary's deeper purpose is **standardizing the questions** the audit asks about each vendor. Without it, each vendor gets read at the depth the auditor happens to bring; with it, every vendor gets a uniform set of columns, so the inconsistencies across wrappers (one with timeouts, one without; one that raises, one that swallows) become visible as a column-diff rather than as scattered prose.

## When it's produced

Once per audit, in the area that owns external integration boundaries. In the pilot's audit this was Area 4a (cross-cutting services). The next codebase may have its vendor boundaries in a different area class; place the summary in whichever area owns them.

## What triggers it

- The area contains wrappers for 2+ external vendors.
- The vendors' failure semantics differ enough that a uniform reference is genuinely useful.
- Subsequent audit work (domain pipelines, incident response, error-handling sweeps) will reference vendor behavior.

## Template

One sub-section per vendor, each containing this matrix:

| Aspect | Behavior |
|---|---|
| Vendor SDK | Which library |
| Wrapper | The wrapper module / class / function |
| On success | What returns; what gets logged |
| On vendor-side rejection (`successful: False`, 4xx, etc.) | What the wrapper does. Does it raise? Return False? Swallow silently? Visible failure or invisible? |
| On Python exception (network, parse, SDK bug) | Same question, different failure shape |
| On vendor timeout / hang | Is there an explicit timeout? What's the default? What blocks if there isn't one? |
| Failure visibility upstream | Do callers see the failure? Or is the wrapper's return value commonly discarded? |
| 1-hour outage system-wide | What's broken across the system if this vendor is down for an hour? Which features fail visibly, which silently? |

Add vendor-specific extra rows where they matter — model pinning for LLM SDKs, SSRF protection for image-fetch wrappers, rate-limit self-throttling for crawlers.

After the per-vendor matrices, an **inter-vendor consistency note** is sometimes worth including: does every wrapper raise on error, or does each wrapper do its own thing? Are exception types normalized to project-specific types, or do vendor SDK exceptions leak through? Are retry / timeout behaviors consistent across wrappers, or improvised per wrapper? This inter-vendor consistency check is where the architectural finding usually lives — see the pilot's #67 (Composio contract) and #76 (unified Anthropic wrapper) for examples.

## Worked example (from the pilot)

`PIC-WORKED-EXAMPLE`. A real instance of this spec, from a cross-cutting-services area report (full instance in the case study, `case-study/pilot/phase-1-area-4a-report.md`), two abridged entries:

### Composio Gmail

| Aspect | Behavior |
|---|---|
| Vendor SDK | `composio` Python SDK |
| Wrapper | `composio_client.send_email` |
| On success | Returns `True`. Logs `"Email sent to {to}: {subject}"` at INFO. |
| On `successful: False` (Gmail rejected) | **Returns `True`** (the wrapper never checks `result.get("successful")`). Invisible failure. — **#67** |
| On Python exception | Logs at ERROR. Returns `False`. Sentry's default `LoggingIntegration` captures the ERROR log as an event. |
| On vendor timeout / hang | Blocks indefinitely. No explicit timeout set. — **#68** |
| Failure visibility upstream | False return ignored by most callers (notifications.py, mailing_list.py); only `contact.py` checks it. — **#70, #74** |
| 1-hour outage system-wide | Customer order confirmations vanish silently; admins not notified of new orders; educator signups silently never receive confirm emails; mailing-list signups silently never get confirm emails. Customer-stranding (Area 2 #36/#37, Area 3 #59 already filed). |

### Anthropic (Claude)

| Aspect | Behavior |
|---|---|
| Vendor SDK | `anthropic` Python SDK |
| Wrapper | **None** — 7 modules, 5 separate `anthropic.Anthropic()` instances. — **#76** |
| On success | Returns `Message`. Token usage is in `message.usage`; **nothing records it.** — **#78** |
| On `anthropic.RateLimitError`, `APIConnectionError`, server-side errors | **Uncaught at all 18 call sites.** Propagates to admin route as 500. Sentry-visible. |
| On malformed JSON response | **Uncaught at 4+ sites; caught at 3 sites.** Inconsistent. — **#77** |
| On refusal block | Would land as text content but with refusal copy, causing downstream `json.loads` to fail. Uncaught everywhere. |
| On vendor timeout / hang | **SDK default is 600 s (10 minutes) per request. No explicit timeout in any call.** — **#68** |
| Failure visibility upstream | Admin 500s. No retry. No budget cap (a runaway loop could burn unbounded credits). |
| Model pinning | Haiku is date-pinned (`claude-haiku-4-5-20251001`). **Sonnet is NOT date-pinned (`claude-sonnet-4-6` — family-current alias).** — **#76** |
| 1-hour outage system-wide | All admin-driven LLM content generation unavailable. Public site is unaffected. Admin re-clicks when service returns. |

Notice the cross-vendor pattern: timeouts are missing on multiple wrappers (#68 is one issue, not five); error visibility is inconsistent (some raise, some swallow). Those are the architectural findings the summary surfaces.

## Pitfalls

- **Treating each vendor as independent.** The point of putting them in one matrix is to surface cross-vendor consistency — which wrappers swallow, which raise, which have timeouts. Read the columns *across* vendors, not just *within* each vendor.
- **Skipping the 1-hour-outage column.** This is where the system-wide impact actually lives, and it's where the operator's prior is usually weakest. "PayPal is down for an hour — what breaks?" is a question the matrix forces the auditor to answer.
- **Failing to cross-reference filed issues.** Each row should cite the issue number(s) it points at. Without citations, the matrix is descriptive only; with them, it's a reading guide for the backlog.
- **Letting the matrix drift toward boilerplate.** If two vendors have identical rows for "on vendor timeout / hang" (both "Blocks indefinitely. No explicit timeout."), that's a cross-cutting finding — file it as one issue (#68 in the pilot) and reference it from each row, rather than treating it as a separate problem per vendor.
