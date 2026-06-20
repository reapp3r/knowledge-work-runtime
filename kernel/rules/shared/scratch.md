---
paths:
  - "**/.scratch/**"
  - "**/tools/**"
  - "**/bin/**"
---

# `.scratch/` — ephemeral local working state

Dot-prefixed folder convention for non-canonical, ephemeral content. Hidden from default directory listings, kept out of the canonical view but available for ad-hoc work.

## Where it's allowed

Any area root: `workspace/.scratch/`, `data/.scratch/`, `tools/.scratch/`, project root `.scratch/` if needed.

## What it's for

One-off scripts, exploration notebooks, ad-hoc data conversions, throwaway prep, build pipelines you're spinning up to produce a single artefact.

**Mandatory home for any temp tool / build script.** If you need to spin up a script to produce a bundle, transform a CSV, render a batch of files, or run any other ad-hoc pipeline, **it goes in `<area>/.scratch/<task-slug>/`**. Never invent new top-level dirs (`tools/build/`, `scripts/`, `temp/`, etc.) — those are convention violations and end up as orphaned cruft.

**Same applies to pipeline run artefacts** — stdout/stderr redirects (`> foo.log 2>&1`), tool output paths (`--output FILE.jsonl`, `--staging DIR`), payload dumps. Never to a root-level dotfile (`.ingest.log`, `.staging/`, `.payload.jsonl`); always `<area>/.scratch/<task-slug>/<name>`. If the tool needs a path, give it a scratch path.

## Lifecycle

- `.scratch/` is **`.gitignored`** — never committed, never assumed present after a clone. Purely local working state.
- Produced artefacts that need to survive go to their canonical location; the scratch that produced them stays local.
- Create freely, sub-organize by task: `.scratch/<task-slug>/`.
- On completion, either: (a) delete the whole task folder if no future value, or (b) add a `README.md` documenting status, link to the artefact produced, and what's safe to drop.
- Anything in `.scratch/` is fair game to delete — by convention, deletion of `.scratch/` content does not require operator authorisation.
- Hardcoded paths in `.scratch/` scripts point to the *current* location of artefacts (update when the artefact's canonical location changes).

## What does NOT go in `.scratch/`

- Anything referenced by canonical material (work units, deliverables, indexes).
- Iteration history of completed work — that goes in an `_archive/` per the owning runtime's layout rule.

## Why dot prefix (not underscore, not no-prefix)

- **Dot prefix** hides scratch from default `ls` and most UI surfaces — keeps the ephemeral working area out of the canonical view without deleting it.
- **Not underscore-prefix** — visible-but-separated didn't pay for itself; scratch is fundamentally working noise and is better tucked away.
- **Not no-prefix** — it would intermingle with canonical folders and the semantic separation is lost.

## Other conventions (for reference)

- `data/` (lowercase, area-local structured data) — rare; distinct from the `data` runtime.
- `.DS_Store` — macOS Finder noise; safe to delete on sight; regenerates harmlessly. Already in `.gitignore`.
