# Fix brief — issue #80: [Quality] mailing_list._send_confirmation_email uses raw f-string HTML; pattern parallel to #31

## Identification

You are an autonomous agent resolving issue #80 in the Panama In Context codebase (`/home/javier/vc/panama-in-context`). You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

- Backend Python. Lint with: `docker-compose exec backend ruff check /app` (and `ruff format /app` to format). Note: ruff is unpinned in this repo (`ruff>=0.1.9`); CI runs latest. Verify your lint is clean against the container's ruff.
- Tests: this issue's test is a **pure template-render test that needs no DB** — mirror `backend/tests/test_notifications.py`, which renders templates directly through the service's `_env` using `SimpleNamespace`/literals and touches no Postgres testcontainer. You do NOT need the full docker stack to write or reason about it. To actually run the suite: `docker-compose exec backend pytest tests/test_mailing_list.py` (or your new test file). If the operator's dev stack is already up on the main checkout, prefer running pytest natively or against the existing container rather than `docker-compose up` from the worktree (port 5432/8000 conflicts). The new escaping test does not require a live container at all.
- **SMTP must stay mocked.** `mailing_list._send_confirmation_email` calls `email_sender.send_email`, which submits to the real SMTP relay. The existing `test_mailing_list.py` patches `app.services.mailing_list._send_confirmation_email` wholesale; your new render test should test the **template rendering** (via the Jinja env), NOT call `_send_confirmation_email` with a live `send_email`. Never let a test hit the SMTP relay.
- `jinja2>=3.1.0` is already a dependency (`backend/requirements.txt:58`). No requirements change, no container rebuild.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope.

In all four: the PR description is where you surface the disagreement. Never silently work around a mismatch.

## The task (verified facts)

Migrate the email bodies in `_send_confirmation_email` (`backend/app/services/mailing_list.py:32-79`) from raw f-string HTML to Jinja2 templates with autoescape, mirroring the pattern issue #31 established in `notifications.py`.

**Issue-body-vs-source drift you must know (source wins):**
- The issue body says the function is at lines 117-157 and returns `bool`. It is actually at **`mailing_list.py:32-79`**, returns **`None`**, and propagates `EmailDeliveryError` on send failure. **Preserve the `-> None` signature and the no-return contract** — its callers (`subscribe` at line 119, `_subscribe_existing` at lines 159 and 181) wrap the call in `try/except EmailDeliveryError` and do NOT inspect a return value. The issue's pseudocode showing `return send_email(...)` is wrong; keep `send_email(email, subject, body)` as a bare call.
- The issue cites the Jinja env at `notifications.py:30-34`; it is actually at **`notifications.py:39-47`** (imports at line 30).

**Canonical pattern to mirror (read these first):**
1. Env + helper — `backend/app/services/notifications.py:30,39-47`:
   ```python
   from pathlib import Path
   from jinja2 import Environment, FileSystemLoader, select_autoescape

   _TEMPLATE_DIR = Path(__file__).resolve().parent.parent / "templates" / "email"
   _env = Environment(
       loader=FileSystemLoader(_TEMPLATE_DIR),
       autoescape=select_autoescape(["html", "xml"]),
   )

   def _render(template_name: str, **context) -> str:
       return _env.get_template(template_name).render(**context)
   ```
   Add this same block (module-level `_env` + `_render`) to `mailing_list.py`. Place the imports with the existing imports at the top of the file; place `_TEMPLATE_DIR`/`_env`/`_render` after the imports (e.g. near `_utcnow`).
2. Single-URL-variable template exemplar — `backend/app/templates/email/admin_magic_link.html`. It has exactly one interpolation (`{{ magic_link_url }}`) in the same button-link style our confirmation email needs. Use it as the structural model.
3. Test pattern — `backend/tests/test_notifications.py:23-37,86-91` (import `_env`, render template, assert escaped form present and raw payload absent; no DB, uses `SimpleNamespace`/literals).

**Concrete changes:**

1. **Create `backend/app/templates/email/subscribe_confirm.es.html`** — port the Spanish body from `mailing_list.py:46-60`, replacing the f-string `{confirm_url}` (an HTML attribute value) with the Jinja variable `{{ confirm_url }}`. Keep the `<html><body ...>` wrapper, the `<h2>`, the button `<a>`, and the footer paragraph exactly as the current HTML (same inline styles, same Spanish copy).

2. **Create `backend/app/templates/email/subscribe_confirm.en.html`** — same, porting the English body from `mailing_list.py:63-77`.

3. **Edit `_send_confirmation_email`** (`mailing_list.py:32-79`) to:
   - Keep the `-> None` signature, the docstring, the `get_settings()` import-and-call, and the `confirm_url = f"{settings.frontend_url}/confirm-subscription?token={token}&lang={language}"` line unchanged.
   - Replace the `if language == "es": ... else: ...` block: keep the subject-selection (`"Confirma tu suscripción a Panama In Context"` for `es`, `"Confirm your Panama In Context subscription"` for `en`), and set the body via `body = _render(f"subscribe_confirm.{language}.html", confirm_url=confirm_url)`.
   - Keep the final bare `send_email(email, subject, body)` call (no return).

4. **Add an escaping regression test.** Render `subscribe_confirm.es.html` and `subscribe_confirm.en.html` through `mailing_list._env` (import it like `test_notifications.py` imports `notifications._env`) with `confirm_url` set to a value containing an HTML payload (e.g. `https://x/?token=<script>alert(1)</script>`), and assert the raw `<script>` does NOT appear while the escaped `&lt;script&gt;` (or `&amp;`/`&#34;` entities) DOES — proving autoescape is active. Add a happy-path assertion that a benign `confirm_url` renders inside the `href`. Put this in `backend/tests/test_mailing_list.py` (new test class) OR a focused new `backend/tests/test_mailing_list_templates.py`; either is acceptable — match the no-DB style of `test_notifications.py`.

**Why this is correct and low-risk:** today's only interpolated value is `confirm_url`, built from a server-generated `token = str(uuid.uuid4())`, the config `settings.frontend_url`, and `language` (already constrained to `Literal["en", "es"]` by `app/schemas/subscribe.py:9,19`). There is no live XSS today; the fix is defense-in-depth + consistency with the post-#31 pattern, so the next edit (e.g. adding a subscriber name) can't reintroduce the injection class.

## Scope

### IN scope
- `backend/app/services/mailing_list.py` — add the `_env`/`_render` block and rewrite the body construction in `_send_confirmation_email`.
- `backend/app/templates/email/subscribe_confirm.es.html` (new).
- `backend/app/templates/email/subscribe_confirm.en.html` (new).
- One test file: `backend/tests/test_mailing_list.py` (add a render/escaping test class) or new `backend/tests/test_mailing_list_templates.py`.

### OUT of scope (do NOT touch)
- Do NOT modify `subscribe`, `_subscribe_existing`, `confirm`, `unsubscribe`, or `_utcnow` in `mailing_list.py` beyond what `_send_confirmation_email` requires. Their control flow, DB writes, and the `educators`-table interaction are out of scope.
- Do NOT change the `_send_confirmation_email` signature (`(email, token, language) -> None`) or its `EmailDeliveryError` propagation behavior.
- Do NOT touch `notifications.py` or any of its existing templates — refactoring a shared env helper across both files is out of scope.
- Do NOT edit `app/schemas/subscribe.py`, `app/api/subscribe.py`, the `Educator` model, or any migration. No input-validation hardening.
- Do NOT change SMTP / `email_sender.py`.
- Do NOT alter the existing tests in `test_mailing_list.py` (the `_send_confirmation_email` patches stay as-is); only ADD a test.

## Default rules for likely ambiguities

- **Template filenames:** `subscribe_confirm.es.html` and `subscribe_confirm.en.html` (mirrors the established `<name>.<lang>.html` convention, e.g. `new_order_customer.en.html`).
- **Jinja variable name:** `confirm_url` (matches the local var passed in).
- **Env config:** copy `notifications.py` verbatim — `FileSystemLoader(_TEMPLATE_DIR)` + `autoescape=select_autoescape(["html", "xml"])`. `_TEMPLATE_DIR = Path(__file__).resolve().parent.parent / "templates" / "email"`. Do not invent a different escaping mechanism (no `markupsafe.escape` calls — autoescape covers it).
- **`_render` helper:** define a module-level `_render(template_name, **context)` identical to `notifications.py:46-47`. (A small duplication of the helper across the two service modules is acceptable and intended — see OUT of scope; do not factor it into a shared module.)
- **HTML copy:** preserve the existing Spanish/English wording, the `#1095d3` colors, and inline styles exactly. Only the `{confirm_url}` interpolation changes to `{{ confirm_url }}`.
- **Test location:** if unsure, add a new `TestSubscribeConfirmTemplates` class inside the existing `test_mailing_list.py`; reuse the escaping-assertion style (`SCRIPT_PAYLOAD`/`SCRIPT_ESCAPED`) from `test_notifications.py`.
- **Import placement:** `from pathlib import Path` and `from jinja2 import Environment, FileSystemLoader, select_autoescape` go with the existing top-of-file imports (after the existing `import` lines), respecting ruff's import ordering.

## Failure-mode escape hatch

If the primary path is blocked — e.g. the template dir resolves wrong, or `_render` can't find the template at runtime — STOP and open the PR as a **draft** with a comment describing exactly what's blocked. Do not silently revert to f-strings.

## Self-review checklist (before opening the PR)

- [ ] Only the in-scope files are modified (`git status` shows nothing else).
- [ ] `_send_confirmation_email` keeps its `-> None` signature, the `confirm_url` construction line, the subject strings, and the bare `send_email(...)` call.
- [ ] Both `subscribe_confirm.es.html` and `subscribe_confirm.en.html` exist and use `{{ confirm_url }}`.
- [ ] The new test renders both templates via `mailing_list._env`, asserts a `<script>` payload in `confirm_url` is escaped (raw absent, entity present), and includes a happy-path render assertion.
- [ ] No test hits the real SMTP relay; existing `test_mailing_list.py` patches are untouched.
- [ ] `docker-compose exec backend ruff check /app` is clean (no new issues vs main baseline); `ruff format` applied.
- [ ] `pytest tests/test_mailing_list.py` (and the new test) passes.
- [ ] PR description complete, including the production-touch line.

## PR shape

- **Branch**: `fix/issue-80-mailing-list-jinja-email`
- **Title**: `fix(#80): migrate mailing_list confirmation email to Jinja2 autoescape templates`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by:"** line (HTML-templating only; no change to `educators` reads/writes, no `.env`, no auth/payment; only interpolated value is the server-controlled `confirm_url`); the self-review checklist with each item marked; a test plan; the noted issue-body line-number/return-type drift; `Closes #80`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced. Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Read the issue (`gh issue view 80`) and the files named above: `backend/app/services/mailing_list.py` (esp. lines 32-79), `backend/app/services/notifications.py:30-47`, `backend/app/templates/email/admin_magic_link.html`, and `backend/tests/test_notifications.py:23-37,86-91`. Confirm the verified facts still hold.
2. Create the two templates.
3. Edit `_send_confirmation_email` and add the `_env`/`_render` block.
4. Add the escaping render test.
5. Run ruff + pytest; iterate until clean.
6. Self-review checklist.
7. Open the PR (draft if any item failed; ready otherwise).
8. Append the outcomes-log row.
9. Report back and STOP.
