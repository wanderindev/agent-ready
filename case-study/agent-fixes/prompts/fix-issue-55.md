# Fix brief — issue #55: dev-token admin bypass activates on DEBUG=true — single env flag flip gives full unauthenticated admin access

## Identification

You are an autonomous agent resolving issue #55 in the Panama In Context (panama-in-context) codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

Scope to OPTION 1 only (tighten the gate + add loud telemetry). Do NOT remove the bypass entirely — that alternative needs a human decision and is explicitly out of scope.

## Operational notes

Backend-only change. The fix is a Settings field + a conditional + logging/Sentry telemetry, plus one new test. It is fully exercisable by pytest against a PostgreSQL testcontainer — no live API access needed.

Run tests natively against a testcontainer (simplest path, no docker-compose needed):
- From the worktree: `cd backend && python -m pytest tests/test_auth.py -q` (install requirements first if the worktree's venv is bare: `pip install -r backend/requirements.txt`).
- If native pytest cannot reach Docker for the testcontainer, fall back to: `docker-compose -p agent-issue-55 -f docker-compose.yml exec backend pytest tests/test_auth.py` — but prefer native. Do NOT attach to the operator's running dev stack (port conflicts on 5432/8000); if you use docker-compose at all, always pass `-p agent-issue-55`.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope.

In all four: the PR description is where you surface the disagreement. Never silently work around a mismatch.

## The task (verified facts)

The dev-token admin bypass at `backend/app/api/dependencies.py:30` currently fires whenever a single flag is true:
```python
if settings.debug and token == "dev-token":
    return _DEV_MAGIC_LINK
```
The risk: one stray `DEBUG=true` in prod opens all admin endpoints to the internet, with no log trace. Make two changes (defense-in-depth):

1. **Add a Settings field** in `backend/app/core/config.py` (alongside `debug: bool = False` at line 9):
   ```python
   environment: str = "production"
   ```
   Default MUST be `"production"`. pydantic-settings maps the env var `ENVIRONMENT` → `environment` case-insensitively (same convention already used by `docker/cert-watcher/check_certs.py:35`, which also defaults to `"production"`).

2. **Tighten the conditional** in `dependencies.py` so BOTH flags must align, and add loud telemetry when the bypass fires. Replace the bypass block (current lines 29-31) with logic equivalent to:
   ```python
   settings = get_settings()
   if settings.debug and settings.environment == "development" and token == "dev-token":
       logger.warning("dev-token admin bypass used for path: %s", <requested path>)
       sentry_sdk.add_breadcrumb(
           category="auth",
           message="dev-token admin bypass used",
           level="warning",
           data={"path": <requested path>},
       )
       return _DEV_MAGIC_LINK
   ```
   - Add module-level `import logging`, `import sentry_sdk`, and `logger = logging.getLogger(__name__)` at the top of `dependencies.py` (mirror `backend/app/services/email_sender.py:14-22`; WARN-level usage mirror: `backend/app/api/media_library.py:379`). `add_breadcrumb` is not yet used anywhere in the backend — this is its first use; the call shape above is correct per the Sentry SDK.
   - **Requested path:** `validate_admin_token` does not currently receive a `Request`. To log the path, add a `request: Request = None` parameter (import `Request` from `fastapi`) and use `request.url.path if request else "<unknown>"`. Default it to `None` so the dozens of existing direct callers (e.g. `db=...` positional usage) and the test patches (`patch("app.api.edu.validate_admin_token", ...)`) are unaffected. If wiring `Request` through proves to require touching callers, fall back to logging without the path (still WARN + breadcrumb) and note it in the PR — the path is a nice-to-have, the WARN+breadcrumb is the requirement.

3. **Enable the bypass for local dev.** With `environment` defaulting to `"production"`, the dev-token bypass would stop working locally unless dev sets it. Add `- ENVIRONMENT=development` to `docker-compose.yml` immediately after `- DEBUG=true` (line 29, the `backend` service `environment:` block). This is the ONLY compose change.

**DRIFT — read carefully (source wins over the issue body):**
- The issue body says prod safety comes from `docker-compose.prod.yml:30 DEBUG=false`. FALSE. The prod backend service (`docker-compose.prod.yml` lines 4-22) sets no inline `DEBUG` and no `environment` block — it uses `env_file: .env` and the config default `debug: bool = False`. The `ENVIRONMENT=production` at prod line 59 belongs to the **cert-watcher** service, NOT the backend. **Therefore `docker-compose.prod.yml` needs NO change**: the backend already gets `environment="production"` from the new default. Do not edit `docker-compose.prod.yml`.
- The real `DEBUG=false` lives in `.env.example:14` (and the gitignored prod `.env`). Do not touch `.env.example` (it has no `ENVIRONMENT` line; adding one is optional polish — see default rules).
- The issue body's `validate_admin_token(token: str, db: Session = None)` signature is simplified; the real signature is `validate_admin_token(token: str = Query(..., description="Admin magic link token"), db: Session = None)`. Preserve the real signature when adding the `request` param.

4. **Add a test** in `backend/tests/test_auth.py` proving the tightened gate: dev-token is rejected when `environment != "development"` even if `debug=True`, and accepted only when both `debug=True` and `environment=="development"`. Use the existing `get_settings` / `lru_cache` (clear it with `get_settings.cache_clear()` or monkeypatch the settings) — mirror how other tests in that file manipulate settings. The `admin_token` fixture (`backend/tests/conftest.py:81`) confirms no existing test relies on the dev-token bypass, so tightening it breaks nothing.

## Scope

### IN scope
- `backend/app/core/config.py` — add `environment: str = "production"` field.
- `backend/app/api/dependencies.py` — tighten conditional, add logging + Sentry breadcrumb, optional `Request` param.
- `docker-compose.yml` — add `- ENVIRONMENT=development` to backend service env block.
- `backend/tests/test_auth.py` — add gate test.

### OUT of scope (do NOT touch)
- `docker-compose.prod.yml` — NO change needed (default covers prod). Do not edit.
- The frontend `AdminAuthContext.jsx` dev-token behavior — unchanged.
- Removing the bypass entirely (the "cleaner alternative") — needs human decision.
- `_DEV_MAGIC_LINK` definition, the magic-link DB query, or any other endpoint.
- `docker/cert-watcher/` — referenced only as a naming precedent.

## Default rules for likely ambiguities

- Settings field name: exactly `environment`. Type `str`. Default exactly `"production"`.
- Env-var value for dev: exactly `development` (lowercase). The comparison is `settings.environment == "development"`.
- Conditional: all three of `settings.debug` AND `settings.environment == "development"` AND `token == "dev-token"` must be true. Order: debug and environment first, token last.
- Log level: WARN (`logger.warning(...)`). Sentry breadcrumb `level="warning"`, `category="auth"`.
- Logger: module-level `logger = logging.getLogger(__name__)` (mirror email_sender.py).
- If threading `Request` into the signature is clean (no caller breakage, since the param defaults to `None`), do it and log the path. If it forces caller changes, omit the path, keep WARN+breadcrumb, and note in PR.
- `.env.example`: optionally add `ENVIRONMENT=production` after the `DEBUG=false` line at :14 for documentation parity — this is harmless polish, allowed but not required. If you add it, keep it `production`.
- Do NOT change the `debug` default or any other existing Settings field.

## Failure-mode escape hatch

If the primary path is blocked — e.g., wiring `Request` would require touching many callers and you can't log the path cleanly — implement the WARN+breadcrumb without the path and note it. If something structurally prevents the tightened conditional, STOP and open the PR as a **draft** describing exactly what's blocked. Do NOT implement the "remove entirely" alternative.

## Self-review checklist (before opening the PR)

- [ ] `environment: str = "production"` added to `config.py`; default is `"production"`.
- [ ] Conditional requires `settings.debug AND settings.environment == "development" AND token == "dev-token"`.
- [ ] WARN log + Sentry breadcrumb (`level="warning"`) fire on bypass; path included if cleanly available.
- [ ] `docker-compose.yml` backend env block has `- ENVIRONMENT=development`; `docker-compose.prod.yml` untouched.
- [ ] New test in `test_auth.py` proves dev-token rejected when `environment != "development"` and accepted only when both flags align; passes.
- [ ] Only the four IN-scope files modified.
- [ ] `ruff check` clean vs main baseline (no new issues); `ruff format` applied.
- [ ] `backend/tests/test_auth.py` passes (and you spot-checked that admin tests using the `admin_token` fixture still pass).
- [ ] PR description complete with "Production touch: no" line.

## PR shape

- **Branch**: `fix/issue-55-dev-token-gate`
- **Title**: `fix(#55): tighten dev-token admin bypass with environment flag + WARN telemetry`
- **Body must include**: one-line summary; a **"Production touch: no — verified by:"** line (config-default + conditional + telemetry; no prod compose/`.env`/DB/deploy change; prod gets `environment="production"` from the default); the self-review checklist with each item marked; a test plan (the new gate test + which existing admin tests you confirmed still pass); the DRIFT note that `docker-compose.prod.yml` needed no change and why; `Closes #55`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced (especially whether the `Request`/path was wired or omitted). Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Read the issue (`gh issue view 55`) and the four files in "The task"; confirm the verified facts still hold (especially that `docker-compose.prod.yml` backend service has no `environment` block).
2. Make the changes, staying strictly within IN scope.
3. Run `ruff check`/`ruff format` and `pytest tests/test_auth.py` per operational notes; iterate until clean.
4. Self-review checklist.
5. Open the PR (draft if any item failed; ready-for-review otherwise).
6. Append the outcomes-log row.
7. Report back and STOP.
