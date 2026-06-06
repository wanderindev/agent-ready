# Methodology docs (to lift)

Placeholder. `methodology-install` copies this directory into a target repo's
documentation tree. It is the **portable extraction unit** — lifted from the
pilot's `docs/methodology/`:

- `README.md` — what the methodology is / isn't, and the extraction procedure.
- `prompt-template.md` — the 10-slot area-audit prompt as a fill-in form.
- `conventions.md` — preserve verbatim prompts; keep the cross-session register
  current; prefer gates to guidelines.
- `cross-cutting-checklist.md` — the six patterns every area audit looks for.
- `cross-session-register.md` — the cross-session decision log (shipped empty).
- `reference-document-types/` — the eight reusable audit deliverable specs.

When lifting, resolve every `PIC-WORKED-EXAMPLE` block: keep the structure, move
the PIC-specific content to the case study, and leave a clearly-marked slot the
`methodology-install` sanitization walk fills per target repo.

Source of truth until lifted: the pilot repo's `docs/methodology/`.
