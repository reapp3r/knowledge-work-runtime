---
name: retro
description: Pull-based continuous-improvement pass — mine session transcripts since the last watermark for recurring corrections the operator gave, merge with the /lesson inbox, propose rule promotions for approval, apply, and track whether promoted rules stick. Run from the project root, on demand (no background automation).
---

# /retro — mine, propose, promote, verify

Pull-based by design: nothing runs automatically; this skill runs when the operator invokes it. State lives in `.claude/retro/`: `last-mined-<hostname>` (ISO watermark — **per machine**, gitignored: transcripts live in each machine's own `~/.claude/projects`, so each machine mines its own backlog), `inbox.md` (/lesson captures, committed), `rules-ledger.md` (every promoted rule + effectiveness tracking, committed).

> Companion: `extract.py` (the transcript sweeper, alongside this SKILL.md). If it isn't present, reimplement it per Step 1.

## 1. Extract

Read `.claude/retro/last-mined-$(hostname -s)` (missing file = mine the full retention window). Run `python3 .claude/skills/retro/extract.py --since <watermark> --out .scratch/retro-mine/<today>/` — it sweeps every `~/.claude/projects/<project-key>*` transcript with mtime past the watermark into compact per-session extracts (the operator's typed messages + truncated assistant context). Reading `~/.claude/projects` needs the per-path authorisation prompt — expected, approve session-scoped. If no new transcripts: report "nothing to mine", check the inbox anyway (step 3), stop.

## 2. Mine and cluster

Fan out one **haiku** agent per extract file, then one **sonnet** clustering agent (Workflow tool). Miner instruction core: find every place the operator gives the assistant feedback about HOW it works — corrections ("no, don't…", "I already told you…"), restated reminders, standing preferences, frustration, process requests; EXCLUDE ordinary task/domain-substance instructions; verbatim quotes ≤300 chars + date + one-line generalized lesson + scope. Clusterer: group into themes, count findings and DISTINCT sessions, rank by cross-session recurrence, severity high at 3+ sessions or visible frustration.

## 3. Merge and screen

Merge themes with `.claude/retro/inbox.md` entries. Then screen against the existing OS — for each theme grep the placement targets (root + runtime CLAUDE.mds, `.claude/rules/**`, agent prompts, actor/entity profiles, hooks) and classify:

- **new** — no placement exists;
- **placed-but-reoffending** — a rule exists, corrections continued after its `rules-ledger.md` date → escalation candidate;
- **covered** — rule exists and no recurrence since its date → record as effective, drop.

**Promotion threshold: 2+ occurrences** (across sessions or inbox+session). Single occurrences stay in the inbox unless the operator marked them standing ("from now on", "always/never").

## 4. Propose — human approval is mandatory

Present a table: theme · evidence (count, sessions, 1–2 quotes) · classification · proposed placement · proposed text (short, behavioral, specific). Placement ladder, strongest first; escalate one rung when a placed rule reoffends:

1. **Deterministic hook** (lint/guard) — for mechanically checkable failures;
2. **Just-in-time injection** (PreToolUse/PostToolUse `additionalContext`, prompt-type Stop guard) — for salience-at-decision-point failures;
3. **Kernel** (runtime CLAUDE.md — re-injected on compact/resume) — for must-never-miss disciplines;
4. **Rule file** (`.claude/rules/**`, path-scoped) — for area-specific operating rules;
5. **Agent prompt** (`.claude/agents/<spec>.md`) — for one specialist's craft;
6. **Actor profile / memory** — actor knowledge → an entity profile; residue per the five-place test in `.claude/rules/shared/canonical.md`.

Promoted rules are FEW, SPECIFIC, BEHAVIORAL ("do X before Y"), date-stamped in the ledger — never bulk-harvested, never vague ("be careful"), never auto-applied. The operator approves/edits/skips each row.

## 5. Apply and close

Apply approved edits per `canonical.md` discipline (edit files, don't append-bucket; curated-area items go through the reference curator queue, never direct writes). **Measure before committing:** char/token delta of every always-loaded or kernel-injected file (`git diff --stat` + `wc -c` vs HEAD) — promotions into CLAUDE.mds and unscoped rules are compressed until the delta is minimal; provenance, anecdotes and incident details go to the ledger, never the loaded surface. Record each applied rule in `rules-ledger.md`: date · rule (one line) · placement path · source evidence · `effective: open`. On later runs, flip to `effective: yes` (no recurrence in 2+ subsequent retro passes) or `escalated → <new placement>` (reoffended). Remove processed inbox lines; write the new ISO timestamp to `last-mined-$(hostname -s)`; report what was promoted, escalated, confirmed effective, and left in the inbox.
