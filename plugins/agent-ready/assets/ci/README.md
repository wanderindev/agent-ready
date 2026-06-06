# CI workflow stubs (to build)

Placeholder. `repo-bootstrap` writes a stack-appropriate CI workflow into the
target's `.github/workflows/`. Planned stubs:

- `python-pytest-ruff.yml` — gitleaks secret scan + ruff lint/format + pytest.
  Modeled on the pilot's `ci.yml`.
- `node.yml` — secret scan + lint + build/test for Node/Vite projects.
- `generic.yml` — secret scan only, as a minimal floor for any repo.

**Load-bearing constraint:** each stub's job `name:` becomes the
branch-protection required-check key. Pick it deliberately; `repo-bootstrap`
must reference the same name when applying protection, and it must never be
renamed afterward.
