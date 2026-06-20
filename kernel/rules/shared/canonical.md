# Canonical — authoring discipline for operational content

You are about to edit a file that defines or governs how this system runs (rule, agent, skill, hook, CLAUDE.md, README.md, memory). Read this first.

## The three layers — each fact lives in exactly one

| File | Audience | Trigger | What belongs |
|---|---|---|---|
| `CLAUDE.md` (root / runtime) | Every turn, always-loaded | Anthropic auto-load | Always-true facts for that runtime. **≤ 200 lines.** |
| `README.md` | Humans + agents on deep-dive | Manual `Read` | Architecture narrative, design rationale — the *why*. |
| `.claude/rules/*.md` | Agents working in matched paths | Auto on path match via `paths:` | Operational specifics — *what to do* in that area. |

Agent-owned layers (not auto-loaded as shell):
- `.claude/memory/generic/*.md` — behavioural rules loaded on every agent dispatch.
- `.claude/memory/context/<name>/*.md` — facts scoped to one work context (a case / project / matter / ticket).
- `.claude/memory/agent/<name>/*.md` — specialist craft; each agent writes only to its own slot.

## Where does this content go?

- Always true for the runtime → `CLAUDE.md` (within the 200-line budget).
- Design / rationale → `README.md`.
- Operational detail needed when touching specific files → `.claude/rules/` with a precise `paths:` glob.
- Behavioural rule agents need on dispatch → `.claude/memory/generic/`.
- Context-specific → `.claude/memory/context/<name>/`.
- End-to-end operator-invoked procedure → `.claude/skills/<name>/SKILL.md`.

## Memory is residue, not default

Before writing to memory, the correction must fail this five-place test in order:

1. **Rule?** Does an existing rule cover this — even partially? Edit the rule.
2. **Hook?** Could this be enforced mechanically? Change the hook.
3. **Tool?** Stale CLI default, missing flag, wrong exit code? Fix the tool.
4. **Skill?** Procedure run end-to-end? Edit the skill.
5. **Agent prompt?** Craft for one specialist? Goes in the agent prompt or `agent/<name>/`.

Only after all five fail does the entry land in memory. Multiple memory writes in one turn = the structural layer needs a fix.

## Edit the file; don't add to it

Before changing anything, read the whole file — know what it is for, what is already there, and how it is structured. Then make the change as an edit: rewrite existing lines so the new fact lives among them, restructure sections that no longer fit, cut what becomes redundant. Pure addition — whether at the bottom, in the middle, or as a fresh section — means you skipped the read and treated the file as a bucket. If nothing in the file relates to what you would add, the question is whether it belongs in this file at all.

## Hard NOs on bloat

- No filler ("it is worth noting", "in general", "importantly").
- No preamble ("before getting into the details").
- No restating the heading in the body.
- No "sometimes you might want to" conditional padding.
- No five examples when one demonstrates.
- No multi-paragraph where one would do.

Every line earns its place. Adding N lines requires either cutting K lines of older content or justifying that the file genuinely grew. **Important rules earn MORE compression, not less.**

## Non-negotiable rules

1. **No duplication across layers.** Restating a rule in CLAUDE.md, in memory, or in another rule is anti-context. Move to its canonical layer; leave a pointer.
2. **No `@path` imports.** Imports are eager and don't reduce context; undocumented for rule files. Use plain markdown links.
3. **CLAUDE.md ≤ 200 lines.** Over-budget content belongs in a rule or in README.
4. **`paths:` must match the files an agent actually touches** when the topic is relevant. Rules don't load on general curiosity.
5. **Rules cannot eagerly load other files.** "Read README §X" is a behavioural instruction, not a mechanical load. Inline operational facts; README for rationale only.
6. **Preserve memory ownership.** Main session writes `generic/`, `context/`; specialists write only their own `agent/<self>/`.
7. **Human-facing rationale in CLAUDE.md** goes in HTML comments — stripped before injection, still readable to maintainers.

## After-action — no ceremony

When a unit of work completes (a deliverable shipped, a schema-touching commit, a frame correction, a surprise), the next turn briefly reviews what worked, what didn't, what gets a rule edit. Most edits land in-turn under the routing test above; deferred items go to a plan/backlog. No file is written.

## Before you save

- Is this fact in exactly one layer?
- If you added a rule, does `paths:` match the files an agent touches?
- Did you cut older content to make room, or is the file genuinely growing?
- If you wrote to memory, did you fail the five-place test?
