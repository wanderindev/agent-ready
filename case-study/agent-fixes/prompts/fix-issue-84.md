# Fix brief — issue #84: orders.py silently swallows all paypal.cancel_invoice failures with bare except: pass

## Identification

You are an autonomous agent resolving issue #84 in the **panama-in-context** codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

- Backend Python (FastAPI + SQLAlchemy). Per `CLAUDE.md`, backend commands run inside Docker.
- This is a **test-only + 4-line-source** change with no live-API need. Simplest path: install backend requirements locally and run `pytest` natively against the PostgreSQL testcontainer (conftest.py spins it up). No docker-compose stack needed.
  - If you prefer docker-compose: the operator's main checkout likely has the dev stack running on ports 5432/8000. Use a dedicated project name (`-p agent-issue-84`) and an alternate-port override file on every call, and `rm` the override before opening the PR. The native-pytest path is recommended here.
- Lint: `ruff check` and `ruff format` must be clean (ruff is unpinned in this repo; CI uses latest — run the latest ruff).
- **PayPal MUST be mocked in tests.** Never hit the real PayPal API. `get_paypal_service()` returns a `PayPalService`; in tests, patch it (e.g. `unittest.mock.patch("app.services.paypal.get_paypal_service")` or patch where `renew_payment_link` imports it: it does `from app.services.paypal import get_paypal_service` *inside the function*, so patch `app.services.paypal.get_paypal_service`).

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description for the reviewer to decide.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope beyond the issue's intent.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

**What the code does now** — `backend/app/api/orders.py`, function `renew_payment_link` (route `POST /{reference}/renew-payment`, lines 443-515). After committing a renewal request, if the order is PayPal with an existing invoice, it cancels the old invoice before a new one is issued. Lines **501-504**:

```python
        paypal = get_paypal_service()
        try:
            paypal.cancel_invoice(order.paypal_invoice_id)
        except Exception:
            pass  # Old invoice may already be cancelled
```

The bare `except Exception: pass` swallows every failure with zero observability (no log, no Sentry).

**Two corrections to the issue body (source wins):**

1. **Line drift**: the issue cites 495-498; the real block is **501-504**. The function is `renew_payment_link` (a *customer* magic-link renewal endpoint), NOT "admin edits an order" as the issue text says. This does not change the fix.

2. **The issue's suggested fix is WRONG about the source — do NOT implement it.** The issue proposes catching `httpx.HTTPStatusError` and special-casing a 422 "already-cancelled" status. But the service method `cancel_invoice` (`backend/app/services/paypal.py:194-214`) does **NOT** call `response.raise_for_status()`. It returns a `bool` (`True` on 200/204, `False` otherwise) and **already** logs `logger.warning(...)` on the non-success HTTP path internally. So a PayPal 4xx/5xx never raises `HTTPStatusError` here — it returns `False`. The bare `except Exception` only ever catches *transport / OAuth / unexpected* exceptions (e.g. `httpx.RequestError` from `client.post`, token-fetch failures). There is no 422 to detect. Ignore the issue's code snippet entirely.

**The fix (observability-only):** replace the silent swallow with a logged, Sentry-captured handler that STILL treats cancellation as best-effort cleanup (does NOT re-raise, does NOT change what is cleared afterward). Concretely, turn lines 501-504 into:

```python
        try:
            paypal.cancel_invoice(order.paypal_invoice_id)
        except Exception as e:
            # Best-effort cleanup: the old invoice may already be cancelled,
            # or PayPal may be transiently unavailable. Do not block renewal,
            # but make the failure observable instead of swallowing it.
            import logging

            import sentry_sdk

            logging.getLogger(__name__).warning(
                "Failed to cancel PayPal invoice %s during renewal of order %s: %s",
                order.paypal_invoice_id,
                order.reference,
                e,
            )
            sentry_sdk.capture_exception(e)
```

Lines 506-508 (clearing `paypal_invoice_id`, `paypal_invoice_url`, setting status `PENDING`) and the final `db.commit()` at 510 stay **byte-for-byte unchanged**.

**Canonical patterns to mirror** (both verified this session):
- `backend/app/services/email_sender.py:56-57` — `logger.error(...)` + `sentry_sdk.capture_exception(e)` (the repo's log-and-capture idiom).
- In-file precedent: `backend/app/api/orders.py:260-264` and `:434-438` use `import logging` (inline) then `logging.getLogger(__name__).error("... %s", ..., e)`. There is **no module-level logger** in `orders.py` — the file's convention is the inline `import logging` form, so mirror that (as shown above). `sentry_sdk` is also imported inline elsewhere (e.g. `auth.py`), so an inline `import sentry_sdk` is consistent.

**Add a test** in `backend/tests/test_orders.py` covering the cancel-failure branch: with `get_paypal_service().cancel_invoice` raising an exception, the renewal endpoint still succeeds (returns 200, clears the invoice fields, sets PENDING) — i.e. the swallow-but-log behavior. Assert the captured exception is logged (you may assert via `caplog` at WARNING level) and that the response is unaffected. Mock PayPal so no real call is made.

## Scope

### IN scope
- `/home/javier/vc/panama-in-context/backend/app/api/orders.py` — replace ONLY the `try/except` at lines 501-504 (within `renew_payment_link`) per "The fix" above.
- `/home/javier/vc/panama-in-context/backend/tests/test_orders.py` — add one test for the cancel-failure branch.

### OUT of scope (do NOT touch)
- `backend/app/services/paypal.py` — `cancel_invoice` already logs its HTTP-failure path correctly; do NOT add `raise_for_status`, do NOT change its return contract.
- The `EmailDeliveryError` handlers at orders.py:255-264 and 433-438 — leave as-is.
- Order/payment control flow: do NOT add `raise HTTPException(...)`, do NOT change whether/when `paypal_invoice_id`/`paypal_invoice_url`/`status` are cleared, do NOT reorder the `db.commit()` calls. The renewal must still succeed on cancel failure (best-effort cleanup). Changing this would be a payment-behavior change and is explicitly forbidden by this brief.
- Any other endpoint or file.

## Default rules for likely ambiguities

- **Exception type**: catch `except Exception as e` (narrowed from bare `except:`). Do NOT try to enumerate `httpx` exception classes — the issue's `HTTPStatusError` approach is invalid for this code (see correction #2).
- **Log level**: `warning` (this is best-effort cleanup that does not fail the request; matches `paypal.py`'s own `logger.warning` for the sibling failure). Use `logging.getLogger(__name__).warning(...)`.
- **Sentry**: yes — `sentry_sdk.capture_exception(e)`, mirroring `email_sender.py:57`.
- **Logger acquisition**: inline `import logging` + `logging.getLogger(__name__)`, mirroring the existing two handlers in this same file. Do NOT add a module-level logger (would be an out-of-scope refactor inconsistent with the file).
- **Imports placement**: inline inside the `except` block (as the two existing handlers do for `logging`) is acceptable and consistent; if ruff prefers module-top imports for `sentry_sdk`/`logging` and flags the inline form, move them to the top of the file — but only if ruff actually flags it. Match whatever keeps ruff clean.
- **Re-raise**: NO. Cancellation is best-effort; the renewal proceeds. Log + capture only.
- **Comment**: keep a short comment explaining best-effort intent (see snippet); do not keep the misleading "Old invoice may already be cancelled" as the *only* rationale since the catch is now broader.
- **Test mocking**: patch `app.services.paypal.get_paypal_service` (the function imports it lazily from that module inside the function body). Make the returned mock's `cancel_invoice` raise an `Exception`. Set up a PAYPAL order with a non-null `paypal_invoice_id` and a valid magic-link token (see existing PAYPAL order setup in test_orders.py around lines 186-210 and how magic links are created/validated — reuse existing fixtures/helpers; do not invent new infrastructure).

## Failure-mode escape hatch

If the primary path is blocked — e.g. you cannot construct a valid magic-link token in the test without out-of-scope plumbing, or `_validate_magic_link` requires fixtures that don't exist — STOP and open the PR as a **draft** describing exactly what's blocked. If only the test is blocked but the 4-line source fix is clean, ship the source fix and open as draft noting the test gap. Do NOT change payment control flow to make testing easier.

## Self-review checklist (before opening the PR)

- [ ] Only the two IN-scope files modified.
- [ ] Source change is confined to the `try/except` at orders.py:501-504; lines 506-510 unchanged byte-for-byte.
- [ ] `except Exception as e` (not bare `except:`); logs via `logging.getLogger(__name__).warning(...)` + `sentry_sdk.capture_exception(e)`; does NOT re-raise.
- [ ] Did NOT implement the issue's `HTTPStatusError`/422 snippet; PR description notes why (paypal.py:194-214 returns bool, no raise_for_status).
- [ ] `paypal.py` untouched; no `raise HTTPException` added; payment behavior unchanged.
- [ ] New test mocks PayPal (no real API call) and asserts renewal still succeeds (200, fields cleared, PENDING) on cancel failure.
- [ ] `ruff check` and `ruff format` clean against the main baseline (no NEW issues).
- [ ] Full relevant test file passes (`pytest backend/tests/test_orders.py`); ideally the full suite.
- [ ] PR description complete, includes the production-touch line.

## PR shape

- **Branch**: `fix/issue-84-paypal-cancel-invoice-logging`
- **Title**: `fix(#84): log and capture swallowed paypal.cancel_invoice failures`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by: observability-only (log + Sentry capture); payment control flow and invoice-clearing logic unchanged byte-for-byte; cancellation remains best-effort, no re-raise"** line; the self-review checklist with each item marked; a test plan; the two issue-body corrections (line numbers 501-504 not 495-498; function is `renew_payment_link` not admin-edit; and that the issue's `HTTPStatusError`/422 fix was rejected because `cancel_invoice` returns a bool and does not `raise_for_status`); `Closes #84`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced (especially the issue-body corrections). Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Read the issue (`gh issue view 84`) and `backend/app/api/orders.py` lines 443-515 plus `backend/app/services/paypal.py` lines 194-214; confirm the verified facts (especially: `cancel_invoice` returns a bool and does NOT call `raise_for_status`).
2. Make the 4-line source change at orders.py:501-504, staying strictly within IN scope.
3. Add the cancel-failure test to `backend/tests/test_orders.py`, mocking PayPal.
4. Run `ruff check`, `ruff format`, and `pytest backend/tests/test_orders.py` (ideally the full suite); iterate until clean.
5. Self-review checklist.
6. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
7. Append the outcomes-log row.
8. Report back and STOP.
