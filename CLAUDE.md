# knowledge-work-runtime — agent contract

This repository is a **reference**, not an application. It packages a Claude Code "operating system" for specialist knowledge work as documentation + drop-in modules, so an agent can read it and **install the OS into another project**.

## Navigating this repo

One doc set, written to be read by whoever opens it. Each doc is short and single-topic, so you open only what a task needs. Two entry points:

- **[`docs/00-overview.md`](docs/00-overview.md)** — the map of the system and the index to every other doc, with a "read this when…" cue per doc.
- **[`manifest.yaml`](manifest.yaml)** — the install catalog: every module's `installs_to`, `verbatim`, and `parameterize`.

## Job A — apply this OS to a target project

Running in another repo, told to "set up knowledge-work-runtime here":

1. Skim `docs/00-overview.md` for the model, then follow **[`apply/runbook.md`](apply/runbook.md)** phase by phase.
2. Pull modules by their `manifest.yaml` `path` as the runbook reaches them; each module's header says where it goes and what to fill in.
3. Open a `docs/*` topic when a step points you to it for detail — you won't need all of them.

## Job B — maintain this reference

Editing this repo itself:

- **`manifest.yaml` is the source of truth for modules.** Any module added/moved/renamed updates its row in the same change. A module with no manifest entry is invisible to the applier — a bug.
- **One fact, one place.** Governed by [`kernel/rules/shared/canonical.md`](kernel/rules/shared/canonical.md): a pattern is explained in exactly one short `docs/*.md` and pointed to from the manifest — never re-explained in the module or duplicated across docs. Keep each doc short; hard anti-bloat.
- **Modules stay generic.** Domain specifics live in `examples/` or as `parameterize` placeholders — never baked into a `kernel/` or `frameworks/` artifact.
- **`verbatim: true` modules copy unchanged** — keep them dependency-free and self-locating (resolve paths via `.git` walk / `BASH_SOURCE`, never cwd or a hardcoded project name).

## What this OS is (one paragraph)

Claude Code reads exactly **one `.claude/` per session**, chosen by the launch directory. This project weaponizes that: a single repo hosts a shared **kernel** (`.claude/` at root: boundary + ownership hooks, the retro improvement loop, authoring discipline) plus several **runtimes** — `workspace` (orchestrator + a dispatched specialist fleet that produces the deliverables), `data` (ingest a large external dataset → classify → index → RAG), `reference` (a curated, tier-ranked authority base), `tools` (first-party CLI source). `cd` into a runtime and you *become* it: its identity, agents, hooks, rules. Only the kernel and `workspace` are mandatory; `data`, `reference`, and `tools` are added by need. Full model: [`docs/00-overview.md`](docs/00-overview.md).
