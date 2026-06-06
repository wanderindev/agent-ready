# Fix brief — issue #46: Two DRY cleanups: duplicate availability query in can_book_slot, hardcoded 48-hour payment_link_expires_at

## Identification

You are an autonomous agent resolving issue #46 in the `wanderindev/panama-in-context` codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

This is two unrelated DRY cleanups bundled into one issue. Do BOTH. Neither changes observable behavior.

## Operational notes

Backend, Python 3.12. The test suite uses **testcontainers** (`backend/tests/conftest.py` spins up an ephemeral `postgres:17-alpine` via the host docker socket) — it does NOT need the dev `docker-compose` stack, and it never touches the operator's running containers or ports. So the simplest correct path is to run pytest natively:

1. From `backend/`: `pip install -r requirements.txt` (use a venv if you like; the worktree is isolated so global install is also fine).
2. Lint exactly as CI does: `ruff check app` (run from `backend/`). CI uses unpinned latest ruff — if a local ruff finding looks like a version artifact, note it but still leave `ruff check app` clean.
3. Tests: from `backend/`, `pytest -q` (Docker must be available for testcontainers; it is). To run just your area: `pytest tests/test_availability.py tests/test_orders.py tests/test_dashboard.py -q`. Do NOT spin up `docker-compose` — you don't need it and it would collide with the operator's dev stack on ports 5433/8000.

Do NOT set a real `DATABASE_URL`; the test client overrides `get_db`. CI runs `pytest --cov=app --cov-report=term -q` with a deliberately bogus `DATABASE_URL` so any code bypassing the override fails loudly — mirror that mindset; don't add code that reads a live DB outside the session.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope beyond the issue's intent.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

### Part 1 — Consolidate the duplicate availability query (`backend/app/services/availability.py`)

The file has TWO methods that run the **same two SELECT queries**:
- `is_slot_available(self, tour_date, time_slot) -> bool` — lines 32-87. Returns a bool.
- `get_blocking_reason(self, tour_date, time_slot) -> str | None` — lines 89-145. Returns a human-readable reason string or None.

Both query (a) PAID/CONFIRMED bookings for the date+slot, then (b) PENDING_PAYMENT/PAYMENT_LINK_SENT bookings joined to `Order` with an unexpired-or-null `reservation_expires_at`. `can_book_slot` (lines 207-231) calls `get_blocking_reason`; callers like `get_availability_range` (147-175) and `get_next_available_date` (177-205) call `is_slot_available`.

(Note: the issue body cites `can_book_slot` at lines 209-233 — the real location is 207-231. Minor drift, no impact on the fix.)

**The fix:** make `get_blocking_reason` the single canonical implementation (it carries strictly more information — the reason string — and `bool(reason)` recovers availability). Then reimplement `is_slot_available` as a thin wrapper:

```python
def is_slot_available(self, tour_date: date, time_slot: str) -> bool:
    """Check if a time slot is available."""
    return self.get_blocking_reason(tour_date, time_slot) is None
```

Keep `get_blocking_reason`'s body exactly as-is (do not change its two queries, its status lists, its reason strings, or the `or_(...)` reservation-expiry logic). Keep `can_book_slot` calling `get_blocking_reason` as it already does. Keep both method names and signatures (external callers depend on `is_slot_available`). Net result: the duplicated query block in `is_slot_available` (lines 43-87) is deleted and replaced by the one-line delegation.

### Part 2 — Replace the hardcoded 48-hour `payment_link_expires_at` (`backend/app/api/booking_admin.py`)

The literal `datetime.utcnow() + timedelta(hours=48)` appears verbatim at:
- `booking_admin.py:417` (inside `send_invoice`, the `@router.post("/orders/{reference}/send-invoice")` handler)
- `booking_admin.py:703` (inside `reschedule_booking`'s PayPal re-issue path, `@router.post("/{booking_reference}/reschedule")`)

(Issue cites 419 and 705; real lines are 417 and 703.)

The canonical config-lookup pattern already exists at `backend/app/api/orders.py:66-69`:

```python
def _get_config_value(db: Session, key: str, default: str) -> str:
    """Get a config value from pricing_config."""
    config = db.query(PricingConfig).filter(PricingConfig.key == key).first()
    return config.value if config else default
```

…used at `orders.py:158`: `reservation_days = int(_get_config_value(db, "reservation_validity_days", "7"))`.

The `PricingConfig` model (`backend/app/models/pricing_config.py`) already documents the key `payment_link_validity_hours` in its docstring (line 22). The key is `String`-valued.

**The fix:**
1. Add a private `_get_config_value(db, key, default) -> str` helper to `booking_admin.py`, copied byte-for-byte from `orders.py:66-69` (including the docstring). Add `PricingConfig` to the `from app.models import (...)` block at `booking_admin.py:12-18` (currently imports `Booking, BookingStatus, BookingStatusLog, Order, OrderStatus` — add `PricingConfig`, keeping the list alphabetised: it goes after `OrderStatus`). `datetime`/`timedelta` are already imported (line 4).
2. Replace BOTH literals (lines 417 and 703) with:
   ```python
   validity_hours = int(_get_config_value(db, "payment_link_validity_hours", "48"))
   order.payment_link_expires_at = datetime.utcnow() + timedelta(hours=validity_hours)
   ```
   Use the local-variable form at each site (do not inline the `int(...)` into the `timedelta` call — readability, and it matches `orders.py:158`'s style of binding the int first).
3. **Default MUST be `"48"`** to preserve current behavior. (The archived seed migration `versions_archive/20260131_seed_tour_booking_data.py:58-60` sets this key to `"24"`, but that migration is out of Alembic's active path — the live chain is `0000_baseline → 0001 → 0002` and does not replay it. The DB may not contain the key at all. Defaulting to `"48"` keeps today's 48-hour behavior regardless of DB state.)

### Part 2b — Keep PayPal's invoice due-date in sync (`backend/app/services/paypal.py`)

`paypal.create_draft_invoice(self, order, bookings, due_hours: int = 48)` (signature at lines 67-72; `due_hours` used at line 97). It is called in two places, neither of which passes `due_hours`:
- `booking_admin.py:374`: `paypal.create_draft_invoice(order, list(order.bookings))` (in `create_invoice`)
- `booking_admin.py:695`: `result = paypal.create_draft_invoice(order, order_bookings)` (in `reschedule_booking`)

**Do this for 2b:** at BOTH call sites, pass the config value explicitly so the invoice due-date stays in sync with `payment_link_expires_at`:
```python
paypal.create_draft_invoice(order, list(order.bookings), due_hours=int(_get_config_value(db, "payment_link_validity_hours", "48")))
```
Leave `paypal.py`'s `due_hours: int = 48` signature default UNCHANGED (it's a sensible fallback and `paypal.py` has no `db` Session to do a lookup of its own). This satisfies the issue's "recommend yes" on keeping `paypal.py:71` in sync without coupling the service layer to the DB.

> NOTE on the hardcoded "48 hours" string in the invoice `terms_and_conditions` (`paypal.py:106`): leave it alone — it is prose, not a computed value, and rewording customer-facing legal text is out of scope.

## Scope

### IN scope
- `backend/app/services/availability.py` — Part 1 consolidation.
- `backend/app/api/booking_admin.py` — Part 2: add `_get_config_value` helper, add `PricingConfig` import, replace the two literals (417, 703), pass `due_hours` at the two `create_draft_invoice` calls (374, 695).
- `backend/tests/` — add/extend tests (see Self-review). New file `backend/tests/test_availability.py` is acceptable if one doesn't exist; otherwise extend the nearest existing booking/availability test.

### OUT of scope (do NOT touch)
- `backend/app/services/paypal.py` signature/default (`due_hours: int = 48`) — leave as the fallback. Only the two CALL sites in `booking_admin.py` change.
- `backend/app/api/dashboard.py` `PRICING_KEYS` (lines 1653-1660) — it does NOT include `payment_link_validity_hours`, and the issue's "admin can tweak it" aspiration would require adding it there + UI work. That is a separate enhancement; do NOT add the key to `PRICING_KEYS`.
- Any Alembic migration. A data-seed migration is NOT required because the code default ("48") preserves behavior. Do NOT write one. (If you feel strongly an idempotent insert-if-absent migration adds value, you MAY add one new file under `backend/alembic/versions/` with `down_revision` pointing at the current head — find it with `cd backend && alembic heads`, or by reading `versions/0002_drop_flask_orphans.py`'s `revision`. But treat this as optional polish, flag it in the PR, and never modify the archived migrations under `versions_archive/`.)
- `orders.py:158` and its `_get_config_value` — that's the canonical pattern; mirror it, don't refactor it. Do not try to hoist `_get_config_value` into a shared module (that would be a cross-file refactor beyond this issue's intent).
- `get_blocking_reason`'s query bodies, status lists, reason strings, and `or_` logic — preserve exactly.
- The invoice `terms_and_conditions` prose in `paypal.py`.

## Default rules for likely ambiguities

- **Which method survives in Part 1:** keep `get_blocking_reason` as canonical; rewrite `is_slot_available` to `return self.get_blocking_reason(...) is None`. Not the other way around.
- **Config default value:** always `"48"` (string), parsed with `int(...)`. Never `"24"`.
- **Helper placement in `booking_admin.py`:** define `_get_config_value` at module level, after the imports and before the first `@router` decorator (mirror where `orders.py` puts it — after `_validate_magic_link`, before the first route). An exact copy of `orders.py:66-69` including its docstring.
- **Import line:** add `PricingConfig` to the existing `from app.models import (...)` tuple in `booking_admin.py` (lines 12-18), alphabetised after `OrderStatus`.
- **Variable name at both literal sites:** `validity_hours`.
- **`due_hours` at the two create_draft_invoice calls:** pass it as a keyword `due_hours=int(_get_config_value(db, "payment_link_validity_hours", "48"))`. Both `create_invoice` (line 339) and `reschedule_booking` (line 600) have a `db: Session` in scope.
- **If `PricingConfig` is somehow already imported** in `booking_admin.py` (it currently is not): don't duplicate the import.

## Failure-mode escape hatch

If the primary path is blocked — a method/field doesn't exist, an import can't resolve, a query consolidation changes a test's expected reason string — STOP and open the PR as a **draft** with a comment describing exactly what's blocked. Don't silently work around it.

## Self-review checklist (before opening the PR)

- [ ] `is_slot_available` is now a one-line delegation to `get_blocking_reason`; the duplicated query block is gone; `get_blocking_reason` body unchanged.
- [ ] Both `hours=48` literals in `booking_admin.py` are replaced with the `_get_config_value(..., "48")` lookup; `grep -rn 'hours=48' backend/app/` returns ONLY `paypal.py:71` (the service-layer default) — no remaining literal in `booking_admin.py`.
- [ ] `PricingConfig` imported in `booking_admin.py`; `_get_config_value` helper present and identical to the orders.py canonical.
- [ ] Both `create_draft_invoice` call sites pass `due_hours=...` from config.
- [ ] `dashboard.py` `PRICING_KEYS` untouched; `paypal.py` signature untouched; no migration to `versions_archive/`.
- [ ] Tests added: at minimum (a) `is_slot_available` and `get_blocking_reason` agree (available ⇔ reason is None) across the blocked and free cases, proving the consolidation is behavior-preserving; (b) the payment-link expiry honors a `PricingConfig(key="payment_link_validity_hours", value=...)` row when present and falls back to 48h when absent. Mock PayPal (`get_paypal_service`) for the booking_admin path — follow existing mocking in `tests/test_orders.py` (it imports `from unittest import mock`).
- [ ] `cd backend && ruff check app` is clean (no NEW findings vs main).
- [ ] `cd backend && pytest -q` is green (full suite — shared helpers can break distant tests).
- [ ] Only in-scope files modified.
- [ ] PR description complete with the production-touch line.

## PR shape

- **Branch**: `fix/issue-46-dry-availability-payment-link-config`
- **Title**: `fix(#46): dedupe availability query and config-drive payment-link expiry`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by:"** line (no prod DB/.env/deploy/auth/PII; behavior preserved via "48" default); the self-review checklist with each item marked; a test plan; the two drift corrections (line numbers 417/703 not 419/705; `can_book_slot` at 207-231 not 209-233) and the noted-but-out-of-scope facts (archived seed = "24"; `PRICING_KEYS` excludes this key); `Closes #46`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced. Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted (if that log file exists; if not, skip and note it).

## Begin by

1. Read the issue (`gh issue view 46`) and open `availability.py`, `booking_admin.py`, `orders.py:66-69`, `paypal.py:67-97`; confirm the verified line numbers still hold (they may shift slightly).
2. Make Part 1 (availability consolidation), then Part 2/2b (booking_admin config lookup + create_draft_invoice due_hours).
3. Add the tests.
4. `cd backend && ruff check app` and `pytest -q`; iterate until clean.
5. Self-review checklist.
6. Open the PR (draft if any item failed; ready-for-review otherwise).
7. Append the outcomes-log row.
8. Report back and STOP.
