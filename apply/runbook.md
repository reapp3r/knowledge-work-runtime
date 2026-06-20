# apply/runbook.md — install this OS into a target project

You are an agent in a **target project**, told to set up knowledge-work-runtime here. Follow these phases in order. Read `manifest.yaml` first; pull each module by its `path` only when you reach it.

> Keep it lean: work from this runbook and `manifest.yaml`. Open a `docs/*` topic only when a step points you to it (it names the file).

## Phase 0 — Orient (don't install yet)

1. Read the target's `README`, top-level dirs, and any existing `.claude/`. Is it already a git repo? (If not, ask before `git init`.)
2. Confirm with the operator before writing anything. Surface what you're about to do and the runtime choices from Phase 1.

## Phase 1 — Decide the runtime set

Always: **kernel + `workspace`.** Then add, by the test in `manifest.yaml > runtimes[].when`:

| Add this runtime | If the project… |
|---|---|
| `data` | has a large external body of source material to ingest, classify, and search/RAG over |
| `reference` | needs a curated, trusted, tier-ranked authority base distinct from raw data |
| `tools` | builds its own command-line tools (skip it if you go pure-MCP) |

Pick the **names** with the operator. The defaults are `workspace / data / reference / tools`; the operator may rename to fit the domain (e.g. `desk`, `sources`, `library`, `bin`). Record the chosen names — they parameterize `SIBLINGS` and `OWNED_AREAS`.

## Phase 2 — Install the kernel (always)

For each `kernel.modules[]` entry, copy `path` → `installs_to` in the target.

- `verbatim: true` modules copy unchanged. They self-locate via `.git` walk / `BASH_SOURCE`; do not edit paths.
- For `parameterize` modules, fill only the listed placeholders:
  - **`boundary_scope.py` → `SIBLINGS`**: the list of runtime dir names + `".claude"` (e.g. `["workspace","data","reference","tools",".claude"]`).
  - **`area-write-gate.sh` → `OWNED_AREAS`**: which runtimes are write-gated and how — own-session-only (workspace, data) vs curator-subagent-only (reference). Tools is typically ungated.
  - **`kernel-inject-sessionstart.sh` → `RECOVERY_REMINDER`**: the per-runtime "re-orient by re-reading X" note (set per runtime in Phase 3, or leave the generic default).
  - **skills → `OPERATOR_NAME`** and `retro`'s `PLACEMENT_TARGETS` (the files retro greps when screening — root + runtime CLAUDE.mds, `.claude/rules/**`, agent prompts).

Wire the hooks into `settings.json`:
- **Root `.claude/settings.json`**: `PreToolUse(Write|Edit|NotebookEdit)` → `area-write-gate.sh`; `SessionEnd` → `git-sync`.
- **Each runtime `<rt>/.claude/settings.json`**: the two boundary hooks (`read-boundary`, `bash-boundary`) on their matchers; `kernel-inject-sessionstart` (SessionStart) + `kernel-inject-userprompt` (UserPromptSubmit) + `precompact-state-dump` (PreCompact); `SessionEnd` → `git-sync`. Boundary/retro hooks are shared via symlink (`<rt>/.claude/hooks/shared → ../../../.claude/hooks/shared`).
- Install the `/lesson` and `/retro` skills and the `canonical.md` + `scratch.md` shared rules at root.

After wiring boundary hooks, run the boundary self-test if present, and verify exit codes (Phase 5).

## Phase 3 — Install the chosen runtimes

For each runtime in the set, scaffold from `runtimes/<rt>/`: a thin `<rt>/CLAUDE.md` (identity + hard boundaries, ≤200 lines — fill the entities/parties placeholder), a `<rt>/.claude/` with `settings.json`, `rules/<rt>/`, `agents/` (workspace + reference only), and `memory/agent/<spec>/`. Set up the cross-runtime symlinks (`hooks/shared`, `rules/shared`, and any cross-runtime agent/skill the manifest notes).

Then install the runtime's framework if it has one:
- `data` → `frameworks/pipeline` (parameterize `CLASSIFICATION_TAXONOMY`, `COLLECTION_TYPES`).
- `reference` → `frameworks/doctype-lint` (parameterize `DOCTYPES`, `TIER_MODEL`, `VERIFICATION_VALUES`).
- `workspace` → `frameworks/schema-lint` (parameterize `SCHEMAS`, `LINK_GRAMMAR`).

## Phase 4 — Parameterize the content

Replace every placeholder the manifest flagged. The big ones:
- **Entities/parties** in each `CLAUDE.md` — the actors in the domain.
- **Classification taxonomy** (`frameworks/pipeline`) — the doc types, themes, and weights for *this* domain. Mechanism stays; vocabulary is yours.
- **Doctypes + tier model** (`reference`) — your authority types and their citability tiers.
- **Work-unit schemas + the agent fleet** (`workspace`) — start from `examples/` and adapt; don't copy the source domain's specialists wholesale.

## Phase 5 — Verify

- **Boundary**: run the boundary self-test; confirm an out-of-scope path is blocked and an in-scope one passes.
- **Exit codes**: every blocking gate must `exit 2` (exit 1 is non-blocking — the action proceeds and the gate silently fails open). Grep the installed hooks.
- **Sandbox (recommended)**: pair the bash-boundary hook with Claude Code's native OS sandbox (`sandbox.enabled: true`, `allowUnsandboxedCommands: false`) — the hook is a guardrail against *accidental* escape, not a security boundary. See `docs/30-boundaries.md`.
- **Symlinks**: confirm each `hooks/shared` / `rules/shared` symlink resolves.
- **cwd test**: launch from each runtime dir and confirm the right `CLAUDE.md` loads and the wrong-area write is gated.

Report what was installed, what was parameterized, and what was skipped (and why).
