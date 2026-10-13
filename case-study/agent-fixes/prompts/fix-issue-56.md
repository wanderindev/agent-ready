# Fix brief — issue #56: Admin allowlist not re-checked when validating tokens — removed admins keep access until token expiry (24h)

## Identification

You are an autonomous agent resolving issue #56 in the Panama In Context codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

Backend-only change (Python). No frontend, no `node_modules`. Main checkout: `/home/javier/vc/panama-in-context`.

Testable via pytest against a PostgreSQL testcontainer. **Prefer native:** `cd backend && python -m pytest tests/test_auth.py -q`. If the backend venv is bare, install first: `cd backend && python -m pip install -r requirements.txt`. The testcontainer needs a reachable Docker socket.

If native pytest cannot reach Docker, fall back to docker-compose with a DEDICATED project name so you never attach to the operator's running dev stack (port conflicts on 5432/8000): always pass `-p agent-issue-56` on every docker-compose call. Do NOT run a bare `docker-compose up -d` from the worktree.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope.

In all four: the PR description is where you surface the disagreement. Never silently work around a mismatch.

## The task (verified facts)

In `backend/app/api/dependencies.py`, `validate_admin_token` (lines 19-44) validates an admin magic-link token by querying `MagicLink` on token + ADMIN_ACCESS action + non-expired. It does NOT re-check the admin allowlist, so a token stays valid for its full 24h window even after the admin is removed from `admin_emails` or marked `is_active=False`.

**The fix:** add a join + filter against `AdminEmail` so the token is only valid while its `admin_email` is still an active allowlist entry. Change the query (currently lines 33-39) to:

```python
magic_link = (
    db.query(MagicLink)
    .join(AdminEmail, AdminEmail.email == MagicLink.admin_email)
    .filter(MagicLink.token == token)
    .filter(MagicLink.action == MagicLinkAction.ADMIN_ACCESS.value)
    .filter(MagicLink.expires_at > datetime.utcnow())
    .filter(AdminEmail.is_active.is_(True))
    .first()
)
```

When this returns no row (deactivated/removed admin), the existing `if not magic_link: raise HTTPException(status_code=401, ...)` fires — no other change to that branch is needed.

**Import:** `dependencies.py` line 10 currently imports `from app.models import MagicLink, MagicLinkAction`. Add `AdminEmail`: `from app.models import AdminEmail, MagicLink, MagicLinkAction`.

**Verified identifiers** (`backend/app/models/magic_link.py`): class `AdminEmail` (table `admin_emails`) with columns `email` (str, unique) and `is_active` (bool); class `MagicLink` (table `magic_links`) with column `admin_email` (str, nullable). The issue's suggested query is accurate — use it verbatim as above.

**Canonical filter pattern to mirror:** `backend/app/api/auth.py:103-108` (`request_admin_access`) already uses `.filter(AdminEmail.is_active.is_(True))` — mirror that `is_(True)` style exactly.

**Drift note for your PR description:** the issue talks about "validating tokens," but the `/auth/verify-token` HTTP endpoint (`verify_token`, `backend/app/api/auth.py:24-83`) has its own separate query and does NOT call `validate_admin_token`. This fix touches `validate_admin_token` ONLY (the helper called directly by the admin/dashboard/edu/booking_admin/media_library routers). The existing admin-token tests in `test_auth.py` exercise `verify_token`, so they will continue to pass unchanged.

**Leave the dev-token bypass intact:** the `if settings.debug and token == "dev-token": return _DEV_MAGIC_LINK` short-circuit (lines 30-31) must remain above the query, untouched. The DB query is only reached for real tokens, so the join does not affect the dev bypass.

**Regression test** — add to `backend/tests/test_auth.py`. The file already imports `from app.models import AdminEmail, MagicLink, MagicLinkAction` and defines helpers `_make_link(db, **kwargs)` and `_make_admin(db, *, email=..., is_active=True)` (lines 39-58). Reuse them. Call the dependency directly (it is a plain function `validate_admin_token(token, db)`, NOT a FastAPI dependency — see all callers passing `(token, db)`). Test asserts:
- Given an active `AdminEmail` row + a fresh ADMIN_ACCESS `MagicLink` for that email, `validate_admin_token(token, test_db)` returns the link (no exception).
- After setting that `AdminEmail.is_active = False` (commit), a second `validate_admin_token(token, test_db)` raises `fastapi.HTTPException` with `status_code == 401`.

Mirror the existing `# ORACLE:` comment convention used in this file for the auth-policy assertion. Import what you need (`from app.api.dependencies import validate_admin_token`, `from fastapi import HTTPException`, `pytest`).

## Scope

### IN scope
- `backend/app/api/dependencies.py` — add `AdminEmail` to the import (line 10); add the `.join(...)` and `.filter(AdminEmail.is_active.is_(True))` to the query in `validate_admin_token`.
- `backend/tests/test_auth.py` — add one regression test (and a test class if it reads cleaner; matching the file's existing `class TestVerifyToken` / `class TestRequestAdminAccess` style).

### OUT of scope (do NOT touch)
- **Do NOT do #54's refactor.** Issue #54 (companion) converts `validate_admin_token` into a proper FastAPI dependency. This fix does NOT do that — keep `validate_admin_token`'s signature and direct-call usage exactly as-is; only add the allowlist join.
- **Do NOT implement the write-time cleanup** the issue calls "also worth considering" (setting `used_at = now()` on a deactivated admin's pending magic links). It touches the admin-deactivation code path, and the read-time join alone fully resolves the stated issue. Explicitly out of scope.
- **Do NOT modify** `backend/app/api/auth.py` (`verify_token` / `request_admin_access`), the `MagicLink`/`AdminEmail` models, any migration, or any of the ~80 router call sites of `validate_admin_token`.
- **Do NOT alter** the `dev-token` debug bypass.

## Default rules for likely ambiguities

- **Join shape:** `.join(AdminEmail, AdminEmail.email == MagicLink.admin_email)` — exactly as written above.
- **Active filter:** `.filter(AdminEmail.is_active.is_(True))` (use `.is_(True)`, mirroring `auth.py:107`), NOT `== True` and NOT `AdminEmail.is_active` bare.
- **Import line:** alphabetical within the existing tuple → `from app.models import AdminEmail, MagicLink, MagicLinkAction`.
- **Test invocation:** call `validate_admin_token(token, db)` directly (positional), not through an HTTP route — it is not wired as a FastAPI `Depends`.
- **Deactivation revocation assertion:** the test must prove a *previously-valid* token returns 401 on the *next* call after the admin's allowlist row goes `is_active=False`. Use the `_make_admin` / `_make_link` helpers; commit the `is_active` change via `test_db` before the second call.
- **No-row outcome:** the join filtering out the row makes `.first()` return `None`, which the existing `if not magic_link:` turns into `HTTPException(401)` — do not add a separate AdminEmail-missing branch.

## Failure-mode escape hatch

If the primary path is blocked (e.g., a referenced field doesn't exist, the testcontainer is unreachable and no fallback works), STOP and open the PR as a **draft** with a comment describing exactly what's blocked.

## Self-review checklist (before opening the PR)

- [ ] Only `backend/app/api/dependencies.py` and `backend/tests/test_auth.py` modified.
- [ ] `AdminEmail` import added; query has both the `.join` and the `.filter(AdminEmail.is_active.is_(True))`.
- [ ] `dev-token` debug bypass and the `validate_admin_token` signature are unchanged (no #54 refactor).
- [ ] No write-time `used_at` cleanup was added.
- [ ] Regression test asserts: valid before deactivation, `HTTPException` 401 after deactivation.
- [ ] `cd backend && python -m pytest tests/test_auth.py -q` passes (all tests, including pre-existing ones).
- [ ] `ruff check backend/app/api/dependencies.py backend/tests/test_auth.py` clean vs main baseline (no new issues).
- [ ] PR description complete with the production-touch line.

## PR shape

- **Branch**: `fix/issue-56-admin-allowlist-recheck`
- **Title**: `fix(#56): re-check admin allowlist when validating tokens`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by: code + test only, no schema/migration/.env/deploy change"** line; the self-review checklist with each item marked; a test plan; the drift note (verify_token vs validate_admin_token); `Closes #56`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced. Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Read the issue (`gh issue view 56`) and the files named above (`backend/app/api/dependencies.py`, `backend/app/models/magic_link.py`, `backend/tests/test_auth.py` helpers at lines 39-58, canonical pattern `backend/app/api/auth.py:103-108`); confirm the verified facts still hold.
2. Add the `AdminEmail` import and the join + active filter in `validate_admin_token`.
3. Add the regression test, mirroring `_make_link` / `_make_admin` and the `# ORACLE:` convention.
4. Run pytest (and ruff) per operational notes; iterate until clean.
5. Self-review checklist.
6. Open the PR (draft if any item failed; ready-for-review otherwise).
7. Append the outcomes-log row.
8. Report back and STOP.
