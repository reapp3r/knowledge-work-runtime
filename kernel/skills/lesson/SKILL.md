---
name: lesson
description: Capture a one-line lesson or correction into the retro inbox without breaking the workflow. Fires on /lesson <text> or when the operator writes "lesson: <text>". Capture only — never analyse or apply at capture time.
---

# /lesson — friction marker

Append one line to `.claude/retro/inbox.md` (project root; create the file with a `# Retro inbox` heading if missing):

```
- YYYY-MM-DD <runtime> — <text as given>
```

`YYYY-MM-DD` from `date +%F`; `<runtime>` is the current cwd area (workspace / data / reference / tools / root). Keep the operator's wording verbatim — no rephrasing, no interpretation.

Then confirm in ONE line ("noted → retro inbox") and return to the interrupted work. **No analysis, no routing, no rule edits at capture time** — that is `/retro`'s job. Capture and analysis are different activities with different costs; this skill exists so capture costs five seconds.
