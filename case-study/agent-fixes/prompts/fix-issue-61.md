# Fix brief — issue #61: No audit log for auth failures — brute force / enumeration attempts are invisible to ops

## Identification

You are an autonomous agent resolving issue #61 in the Panama In Context (`panama-in-context`) codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

**SCOPE BOUNDARY — read first.** This issue describes three layers. You implement **LAYER 1 ONLY: structured log entries + Sentry breadcrumbs at auth-failure sites.** Layer 2 (the `auth_audit_log` table) requires an Alembic migration and is explicitly DEFERRED by the issue body ("Recommended to ship layer 1 first"). Do NOT create a table, model, or migration. Layer 3 (breadcrumbs) is folded into layer 1 since the canonical pattern already pairs a log line with a breadcrumb.

**PRODUCTION-TOUCH BOUNDARY.** This code lives in the auth subsystem and the educator access gate. Your change adds ONLY logging + breadcrumbs. Every `return`, `raise`, and auth decision must stay byte-for-byte identical. You are adding observability *around* existing auth paths, not changing auth behavior. If you find yourself altering a control-flow branch, a return value, or a DB write — STOP; you have left scope.

## Operational notes

This is a backend (FastAPI/Python) change. It is logging-only with assertions against existing test files — you do NOT need a live API or the full docker-compose stack.

Run tests natively against a Postgres testcontainer (simplest path):
- The test suite uses a Postgres testcontainer via `backend/tests/conftest.py`; pytest spins it up. You need Docker available (the socket) but NOT the dev stack.
- From the worktree: install backend requirements, then run pytest from the `backend/` dir. Example: `pip install -r backend/requirements.txt` (or `requirements-dev.txt` if present), then run pytest scoped to the touched files (see self-review).
- If you instead choose docker-compose, the operator's main checkout often has the dev stack running on ports 5432/8000 — a naïve `docker-compose up` will hit port conflicts and/or attach to the operator's containers (whose code volume is the main checkout, not your worktree). If you go that route: use a dedicated project name `-p agent-issue-61` on every call, write a throwaway `docker-compose.agent.yml` with alternate host ports and `user: "0:0"` on backend, reference both via `-f docker-compose.yml -f docker-compose.agent.yml`, and `rm` the override before opening the PR (do not commit it). For this logging-only issue the native-pytest path is recommended.

Lint: this repo uses `ruff`. Run `ruff check` and `ruff format` against the files you touch and confirm no NEW issues vs the main baseline.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope beyond the issue's intent.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

Add a structured `logger.warning(...)` line AND a `sentry_sdk.add_breadcrumb(...)` at each auth-failure site, mirroring the EXISTING canonical pattern already in the repo.

**Canonical pattern to mirror — `backend/app/api/dependencies.py:41-47`** (the dev-token bypass already does exactly this):
```python
logger.warning("dev-token admin bypass used for path: %s", path)
sentry_sdk.add_breadcrumb(
    category="auth",
    message="dev-token admin bypass used",
    level="warning",
    data={"path": path},
)
```
Use `category="auth"`, `level="warning"`, a stable `message`, and a `data` dict of the fields you can capture WITHOUT changing function signatures or call sites. Each log line should carry consistent named fields: an `event` name, a `reason`, and `email` when one is in scope at that site. Use `%s` lazy-logging style (as the canonical pattern does), not f-strings, for the message args.

**The 6 required sites** (verified line numbers, current source):

1. `backend/app/api/dependencies.py:60` — inside `if not magic_link:` before `raise HTTPException(401)`. `event="admin_token_validate"`, `reason="invalid_or_expired_token"`. No email available (only the token). Do NOT log the raw token.
2. `backend/app/api/auth.py:42-43` — `verify_token`, `if not magic_link:` branch. `event="magic_link_verify"`, `reason="token_not_found"`.
3. `backend/app/api/auth.py:46-47` — `verify_token`, expired branch. `event="magic_link_verify"`, `reason="token_expired"`.
4. `backend/app/api/auth.py:110` — `request_admin_access`, `if not admin:` branch (the silent no-op enumeration path). `event="admin_login_request"`, `reason="email_not_in_allowlist"`, `email=request.email`.
5. `backend/app/services/educator_service.py:332-333` — `verify_code`, `if educator is None:` branch. `event="educator_verify_code"`, `reason="email_not_found"`, `email=email`.
6. `backend/app/services/educator_service.py:338-339` — `verify_code`, invalid-code branch (`if not educator.verify_code or educator.verify_code != code:`). `event="educator_verify_code"`, `reason="invalid_code"`, `email=email`. Do NOT log the submitted `code` value.

**Optional within-intent sites** (add if clean; flag as added in PR description): `educator_service.py:153` login `not_found`/UNSUBSCRIBED branch (`event="educator_login"`, `reason="email_not_found"`); `educator_service.py:341-346` `verify_code` expired branch (`reason="code_expired"`). These are the same shape; include them if they don't complicate the diff.

`logger` already exists in all three files (`logger = logging.getLogger(__name__)` at `dependencies.py:14`, `educator_service.py:21`; `auth.py` has no module logger — add `import logging` + `logger = logging.getLogger(__name__)` at module top, matching the other two files). `sentry_sdk` is already imported in `dependencies.py:7`; in `auth.py` and `educator_service.py` add `import sentry_sdk` at the top alongside existing imports.

**Drift corrections (source wins):**
- Issue cites `dependencies.py:19-44` for the 401 path; the actual `raise HTTPException(401)` is at **lines 60-61**. Instrument site 1 there.
- The issue's schema field `source_ip` (and `user_agent`) is NOT capturable at these sites without structural change — see OUT-of-scope. Omit it. Sentry already runs with `send_default_pii=True` (`main.py`) and its FastAPI integration attaches request/IP context to events automatically, so the breadcrumbs will still land in a request-scoped Sentry event with IP context where a request exists. Note this in the PR description.

## Scope

### IN scope
- `backend/app/api/dependencies.py` — site 1.
- `backend/app/api/auth.py` — sites 2, 3, 4 (+ module-level `import logging`, `import sentry_sdk`, `logger = logging.getLogger(__name__)`).
- `backend/app/services/educator_service.py` — sites 5, 6 (+ optional sites; `import sentry_sdk` at top).
- `backend/tests/test_auth.py` — add assertions that the failure branches emit the expected log (use `caplog`) and/or breadcrumb. Extend; do not rewrite. Respect the `# ORACLE:` assertions already there — do not weaken them.
- `backend/tests/test_educator_service.py` — same, for sites 5/6.

### OUT of scope (do NOT touch)
- **NO `auth_audit_log` table, model, or Alembic migration.** Layer 2 is deferred. (Also: schema migrations fail agent-friendly criterion #3.)
- **NO `source_ip` / `user_agent` capture.** This would require threading a `Request` object through `validate_admin_token` (called as a plain function `validate_admin_token(token, db)` at 10 sites in `admin.py` — its `request` param is never injected) and through the educator service functions (which take `db, email, ...`, no `Request`). Changing those signatures and 10+ call sites is structural scope-creep. Leave it.
- **NO changes to any auth decision, return value, raised exception, or DB write.** The branches you instrument must behave identically after your change.
- Do NOT touch `backend/app/api/admin.py`, `backend/app/api/educators.py` (the routers), `backend/app/main.py`, or `conftest.py`.
- Do NOT add `logging.basicConfig` or reconfigure logging globally — the project relies on uvicorn/Sentry default logging handling; module loggers are sufficient.

## Default rules for likely ambiguities

- **Field naming:** use snake_case keys `event`, `reason`, `email`, `endpoint` in breadcrumb `data` dicts. Only include keys whose values are actually in scope at that site (e.g. no `email` at site 1).
- **Never log secrets:** do not log raw tokens, the 6-digit `code`, or `confirm_token` values. Log the *fact* of failure and the reason, plus `email` where the attempt targets a known field.
- **Log message format:** `logger.warning("auth failure: %s (%s)", event, reason)` style, or similar consistent shape — pick one and apply it to all 6 sites identically. Use `%s` lazy args, not f-strings.
- **`auth.py` module logger:** add it at module top (after the existing imports) exactly like `dependencies.py:14` / `educator_service.py:21`.
- **Tests:** prefer `caplog` (pytest fixture) to assert the WARNING log was emitted with the expected `event`/`reason`. If asserting breadcrumbs is awkward to mock, asserting the log line is sufficient — the breadcrumb mirrors the canonical pattern and is low-risk. Do NOT introduce new fixtures requiring DB/test-container plumbing beyond what the existing tests already use.
- **If `educator_login` already logs** an error on the EmailDeliveryError path (`educators.py:48`) — that's a different (router) layer; leave it. Your educator-side instrumentation is in the SERVICE functions only.

## Failure-mode escape hatch

If the primary path is blocked — e.g. instrumenting a site would force an auth-decision change, or capturing a required field is structurally impossible — STOP and open the PR as a **draft** with a comment describing exactly what's blocked. The issue says "the minimum acceptable improvement is layer 1," so layer-1-only (logs + breadcrumbs, no table, no source_ip) is a fully acceptable, complete outcome — not a partial one. Do NOT attempt layer 2 to "finish the issue."

## Self-review checklist (before opening the PR)

- [ ] Only the in-scope files modified (3 source files + up to 2 test files); `admin.py`/`educators.py`/`main.py`/`conftest.py` untouched.
- [ ] All 6 required sites instrumented; each has BOTH a `logger.warning` and a `sentry_sdk.add_breadcrumb` mirroring `dependencies.py:41-47`.
- [ ] No auth decision, return value, raised exception, or DB write changed — diff is additive logging only.
- [ ] No raw token / code / confirm_token logged.
- [ ] No table, model, or migration created; no `source_ip`/`user_agent` threading.
- [ ] `ruff check` and `ruff format` clean vs main baseline (no NEW issues).
- [ ] New/extended tests pass: `pytest backend/tests/test_auth.py backend/tests/test_educator_service.py` green; the existing `# ORACLE:` assertions still pass unmodified.
- [ ] PR description complete, including the **"Production touch: no — verified by:"** line (verified: additive logging only, no auth-decision/return/DB/schema change).

## PR shape

- **Branch**: `fix/issue-61-auth-failure-audit-logging`
- **Title**: `fix(#61): add structured logs + Sentry breadcrumbs for auth failures (layer 1)`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by: additive logging/breadcrumbs only, no auth-decision/return/DB/schema change"** line; the self-review checklist with each item marked; a test plan; an explicit note that layer 2 (`auth_audit_log` table) and `source_ip` capture were intentionally deferred (migration + structural change, out of scope per issue body); `Closes #61` — **but note** issue #61 is only partially addressed (layer 1). Prefer "Addresses #61 (layer 1)" over auto-closing if the operator may want layers 2/3 tracked; default to `Closes #61` only if confident. State your choice in the body. Include the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped (which sites instrumented, including any optional sites added), and any flags you surfaced. Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Issue # 61, Filed agent-friendly? yes, Filed severity moderate, Track backend, Brief reviewed? (per orchestrator), PR # (yours), Outcome not-yet-attempted, Reviewer interventions blank.

## Begin by

1. Read the issue (`gh issue view 61`) and the three source files + two test files named above; confirm the verified line numbers still hold (sites at `dependencies.py:60`, `auth.py:42/46/110`, `educator_service.py:332/338`).
2. Read the canonical pattern at `dependencies.py:41-47` and mirror it.
3. Make the additive logging change at the 6 sites (+ optional), staying strictly within IN scope.
4. Add/extend tests in `test_auth.py` and `test_educator_service.py`.
5. Run `ruff check`, `ruff format`, and `pytest` on the touched test files; iterate until clean.
6. Self-review checklist.
7. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
8. Append the outcomes-log row.
9. Report back and STOP.
