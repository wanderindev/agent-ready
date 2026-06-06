# CI workflow stubs

`repo-bootstrap` copies one of these into a target's `.github/workflows/ci.yml`
and adapts it to the project (language version, working directory, commands).

| Stub | For | Required-check contexts (job `name:` values) |
|---|---|---|
| `python-pytest-ruff.yml` | Python projects | `Secret scan`, `Test` |
| `node.yml` | Node / Vite projects | `Secret scan`, `Test` |
| `generic.yml` | any stack (minimal floor) | `Secret scan` |

All three include a gitleaks **secret scan** as a required check. The Python and
Node stubs add a `Test` job (lint + format/build + tests).

**Load-bearing constraint:** each job's `name:` becomes the branch-protection
required-check key. `repo-bootstrap`'s `protect-branch.sh` must be passed the
same names, and they must never be renamed afterward (renaming strands the
required check forever). Change steps, not names.
