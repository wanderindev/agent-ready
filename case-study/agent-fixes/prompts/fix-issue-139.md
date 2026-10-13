# Fix brief — issue #139: [Quality] Dev backend container doesn't mount /var/run/docker.sock — testcontainers-backed pytest is un-runnable via docker-compose exec

## Identification

You are an autonomous agent resolving issue #139 in the Panama In Context (`panama-in-context`) codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

This fix edits **`docker-compose.yml`** — the DEV compose file at the repo root. It is a tiny, mechanical change (two lines added to one service). The hard part is VERIFYING it without disrupting the operator.

**Do NOT run a naive `docker-compose up -d` or `docker-compose exec` from your worktree.** The operator's main checkout almost certainly has the dev stack running, binding host ports 8000 (backend), 5173 (frontend), 5433 (db→5432), 9000/9001 (minio). A default `docker-compose` invocation from your worktree shares the default compose project name and would either collide on those ports or attach to the operator's containers (whose code volume is the main checkout, not your worktree). Either outcome disrupts the operator. AVOID THAT.

Because this is a config-only change with no app code to exercise, prove correctness using these two NON-disruptive steps — do NOT bring up the full stack:

1. **Static validation (always):**
   `docker compose -f docker-compose.yml config | grep -A30 'backend:'`
   Confirm the rendered config shows your new `/var/run/docker.sock` volume entry and `user: "0:0"` under the backend service. `docker compose config` does not start anything and does not touch the operator's stack.

2. **Isolated functional proof (preferred; skip only if the daemon is unreachable from your worktree):** run a one-shot, fully-isolated container under a dedicated project name and alternate ports, mounting the socket, and run a small testcontainers-backed test. Use a TEMP, NON-COMMITTED override so you never alter committed port mappings:

   - Write `docker-compose.agent.yml` (temp, do NOT commit) next to `docker-compose.yml` containing ONLY alternate host-port overrides for `backend`, `db`, `frontend`, `minio` (e.g. backend `18000:8000`, db `15433:5432`, frontend `15173:5173`, minio `19000:9000`/`19001:9001`) so nothing collides with the operator.
   - Run everything with BOTH `-p agent-issue-139` AND `-f docker-compose.yml -f docker-compose.agent.yml` on EVERY docker-compose call:
     ```
     docker compose -p agent-issue-139 -f docker-compose.yml -f docker-compose.agent.yml up -d backend db
     docker compose -p agent-issue-139 -f docker-compose.yml -f docker-compose.agent.yml exec -T backend pytest tests/test_series_sections.py -q
     ```
     (Test path is INSIDE the container, where `backend/tests` is mounted at `/app/tests`, so it is `tests/test_series_sections.py`, not `backend/tests/...`. The acceptance criterion is this suite passing.)
   - TEAR DOWN COMPLETELY when done: `docker compose -p agent-issue-139 -f docker-compose.yml -f docker-compose.agent.yml down -v`
   - `rm docker-compose.agent.yml` BEFORE opening the PR. It must NEVER be committed. (Belt-and-suspenders: confirm `git status` shows only `docker-compose.yml` changed.)

   If the docker daemon is unreachable from inside your worktree environment (e.g. nested-container limitation), step 2 may be structurally impossible — that's acceptable. In that case rely on step 1 (static `config` validation) plus your reading of the canonical prod pattern, and note in the PR description that functional bring-up could not be performed in the worktree and the operator should run the documented `docker-compose exec backend pytest` to confirm.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description for the reviewer to decide.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope beyond the issue's intent.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

`backend/tests/conftest.py` uses `testcontainers` (`from testcontainers.postgres import PostgresContainer`, line 12; `PostgresContainer("postgres:17-alpine")`, line 19). testcontainers talks to the Docker daemon over the unix socket via its own bundled docker Python SDK — it does NOT shell out to a `docker` CLI. So the container running pytest must (a) have the host docker socket mounted and (b) have permission to read it. `testcontainers>=3.7.1` is in `backend/requirements.txt:40`. No `docker` CLI or extra `docker` python package is needed; do NOT add any.

Current state — verified: the `backend` service in `docker-compose.yml` (lines 18–40) has NO `/var/run/docker.sock` mount. Its `volumes:` are source-mount + `backend_static` only (lines 31–36). The backend image (`backend/Dockerfile:20–21`) runs as a non-root user: `useradd -m -u 1000 appuser` then `USER appuser`. The host docker socket is `root:docker`, mode 660 — so a bare socket mount under `USER appuser` (uid 1000, not in the host docker group inside the container) FAILS with a permission error. This is why the issue's "one-line change" is insufficient.

**The fix** (apply to the `backend` service block in `docker-compose.yml`, lines 18–40, ONLY):

1. Add the socket mount to `backend.volumes:` (mirror the exact syntax already used in `docker-compose.prod.yml:45` / `:66`):
   ```yaml
   - /var/run/docker.sock:/var/run/docker.sock
   ```
2. Add a `user:` override to the `backend` service so the container process can read the root-owned socket:
   ```yaml
   user: "0:0"
   ```
   Place `user: "0:0"` as a sibling key of `backend.volumes`/`backend.environment` (e.g. just under `build:` or above `ports:`). Running the DEV backend as root is acceptable and is the simplest portable way to grant socket access (the host docker group GID varies per machine, so hardcoding a `group_add` GID is not portable). This is dev-only; prod is unaffected.

**Issue-body-vs-source drift to note in your PR:**
- The issue says "the prod compose does not need this." In fact `docker-compose.prod.yml` ALREADY mounts `/var/run/docker.sock` — but on its `certbot` (line 45) and `watchtower` (line 66) services, NOT on its `backend` service. Your change is still dev-only; you must NOT add any socket mount to the prod compose. Just note the observation.
- The issue frames Option A as a single-line change; it is actually two lines (socket mount + `user: "0:0"`) because of the `USER appuser` in the Dockerfile. Implement the corrected two-line version.

Implement **Option A** (mount the socket in dev compose). Do NOT implement Option B (migrating conftest off testcontainers) — that is larger and explicitly operator-driven per the issue.

## Scope

### IN scope
- `/home/javier/vc/panama-in-context/docker-compose.yml` — the `backend` service block ONLY (lines 18–40): add the docker.sock volume line and the `user: "0:0"` key.

### OUT of scope (do NOT touch)
- `docker-compose.prod.yml` — the PRODUCTION compose. Do NOT edit it. Do NOT add a docker.sock mount to its `backend` service. Mounting the socket into a prod backend would be a security regression. HARD FENCE.
- `backend/tests/conftest.py` — do NOT migrate it off testcontainers (that is Option B, out of scope).
- `backend/Dockerfile` — do NOT change the image's `USER`; the dev-compose `user:` override is the correct lever.
- `backend/requirements.txt` — do NOT add `docker` or any package; testcontainers already covers it.
- The `frontend`, `db`, `minio`, `minio-init` services in `docker-compose.yml` — untouched (except, transiently, in your NON-committed `docker-compose.agent.yml` port-override used only for isolated verification, which you delete before the PR).
- `CLAUDE.md` — the issue mentions it documents the test command, but no edit is required; the fix makes the documented command work. Do not edit docs.

## Default rules for likely ambiguities

- **Exact volume line:** `- /var/run/docker.sock:/var/run/docker.sock` (identical to prod's lines 45/66). Add it to the existing `backend.volumes:` list, after the `backend_static:/app/static` entry.
- **User override value:** `user: "0:0"` (root). Do NOT attempt `group_add` with a hardcoded docker GID — non-portable across hosts.
- **Do NOT add `DOCKER_HOST`** to the backend `environment:`. testcontainers defaults to `unix:///var/run/docker.sock`, which is exactly what you mounted. Adding it is unnecessary noise.
- **YAML placement:** keep alphabetical/logical neatness consistent with the file's existing style; the keys' order within a service does not matter functionally — just keep `user:` as a top-level key of the `backend` service, not nested under `environment`/`volumes`.
- **Version key:** leave the top-level `version: '3.8'` as-is; do not "modernize" the compose file.
- **If the isolated functional verification (operational note step 2) is impossible** in your worktree environment, fall back to static `config` validation and say so in the PR — do NOT open as draft solely for that reason (it's an environment limitation, not a fix defect). Use judgment per the self-review checklist.

## Failure-mode escape hatch

If the primary path is blocked — e.g. `docker compose config` reports the file is invalid after your edit, or the change would require touching out-of-scope files — STOP and open the PR as a **draft** with a comment describing exactly what's blocked. A draft PR with an honest "blocked on X" comment is a good outcome; a non-draft PR that silently worked around a block is worse.

## Self-review checklist (before opening the PR)

Run this list. If any item fails, open the PR as a **draft** with a comment naming the failed item.

- [ ] Only `docker-compose.yml` is modified (`git status` shows exactly one changed file; no `docker-compose.agent.yml` present).
- [ ] The added volume line is exactly `- /var/run/docker.sock:/var/run/docker.sock`, under `backend.volumes`.
- [ ] `user: "0:0"` added to the `backend` service.
- [ ] `docker-compose.prod.yml` is UNCHANGED (`git diff --stat` confirms).
- [ ] `docker compose -f docker-compose.yml config` renders without error and shows both new entries under `backend`.
- [ ] (If achievable) isolated `-p agent-issue-139` bring-up ran `tests/test_series_sections.py` to a pass; isolated stack torn down with `down -v`; temp override removed. If not achievable, the PR description says why and instructs the operator to run the documented command.
- [ ] PR description includes the production-touch line and the prod-compose-already-mounts-sock drift note.

## PR shape

- **Branch**: `fix/issue-139-dev-docker-sock`
- **Title**: `fix(#139): mount docker.sock in dev backend so testcontainers pytest runs`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by: change is in docker-compose.yml (dev compose only); docker-compose.prod.yml unchanged (git diff --stat)"** line; the self-review checklist with each item marked; a test plan (the `docker compose config` validation and, if run, the isolated `-p agent-issue-139` pytest pass); the two drift notes (prod compose already mounts sock on certbot/watchtower; two-line not one-line fix); `Closes #139`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass (the isolated functional run being skipped due to an environment limitation does NOT force draft, provided the PR explains it); draft otherwise.
- **DO NOT MERGE.** The operator merges. The `gh pr merge*` deny rule blocks you anyway.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced. Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Read the issue (`gh issue view 139`) and `docker-compose.yml` (backend service), `docker-compose.prod.yml:45,66`, `backend/Dockerfile:20-21`, and `backend/tests/conftest.py:12,19`; confirm the verified facts still hold.
2. Edit ONLY the `backend` service in `docker-compose.yml`: add the docker.sock volume line and `user: "0:0"`.
3. Validate with `docker compose -f docker-compose.yml config`.
4. If feasible, run the isolated `-p agent-issue-139` functional proof per Operational notes (temp override, alternate ports, `down -v`, `rm` the override). Otherwise document the environment limitation.
5. Self-review checklist; confirm `git status` shows only `docker-compose.yml`.
6. Open the PR (ready-for-review if checklist passes; draft otherwise).
7. Append the outcomes-log row to `docs/agent-fixes/agent-friendly-outcomes.md`.
8. Report back and STOP.
