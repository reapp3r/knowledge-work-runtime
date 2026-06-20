---
name: install-knowledge-work-runtime
description: Install the knowledge-work-runtime OS (kernel + chosen runtimes) into the current project. Fires when the operator asks to "set up knowledge-work-runtime here", "install the knowledge-work OS", or points Claude Code at the knowledge-work-runtime repo and says to implement it. Reads the repo's manifest, follows its runbook, installs and parameterizes the kernel + needed runtimes, and verifies.
---

# Install knowledge-work-runtime

A thin entry point. The real procedure lives in the reference repo — this skill just drives it.

1. **Locate the reference.** Either a local clone or the GitHub repo. If only a URL, clone it to `.scratch/knowledge-work-runtime/` (or read it via the tools available). The repo root holds `manifest.yaml`, `apply/runbook.md`, and the `kernel/ runtimes/ frameworks/` modules.

2. **Read `manifest.yaml` first.** It is the entire catalog; every module is self-describing (`installs_to`, `verbatim`, `parameterize`). Do not crawl the tree.

3. **Follow `apply/runbook.md` phase by phase:** orient → decide the runtime set (kernel + workspace always; data/reference/tools by need) → install the kernel → install chosen runtimes → parameterize (names, entities, taxonomy, schemas, fleet) → verify (boundary self-test, exit-2 audit, symlink + cwd checks).

4. **Confirm before writing.** Surface the runtime choices and names to the operator before installing. Respect the target's existing `.claude/` — extend, don't clobber.

5. **Report** what was installed, parameterized, and skipped.

Keep it lean: work from `apply/runbook.md` + `manifest.yaml`; open a `docs/*` topic only when a step references it.
