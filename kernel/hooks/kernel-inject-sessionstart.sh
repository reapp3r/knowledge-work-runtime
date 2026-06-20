#!/usr/bin/env bash
# SessionStart hook — on source: "compact" or source: "resume", re-injects the
# runtime CLAUDE.md plus a one-time post-compact recovery reminder via
# hookSpecificOutput.additionalContext. Resets the UserPromptSubmit prompt count
# so the kernel re-injection cadence restarts cleanly. Sources CLAUDE.md directly
# — no separate kernel file, no drift surface.
#
# Install one copy per runtime, under <runtime>/.claude/hooks/<runtime>/. It
# self-locates the runtime root from its own path (../../.. from the hook dir),
# so it re-injects THAT runtime's CLAUDE.md.
#
# PARAMETERIZE: RECOVERY_REMINDER — the per-runtime "before working this turn,
# re-orient by re-reading X" note (e.g. the orchestrator points at its active
# context/orientation files; a pipeline runtime points at its pipeline state).
# Leave the generic default if the runtime has no orientation triad.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
KERNEL_PATH="${REPO_ROOT}/CLAUDE.md"
STATE_DIR="${REPO_ROOT}/.scratch/hook-state"
COUNT_FILE="${STATE_DIR}/prompt-count"

# Read hook input (JSON on stdin) — extract source field to gate behaviour.
INPUT=$(cat || true)

# Default to "startup" if source can't be parsed.
SOURCE=$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin)
  print(d.get("source","startup"))
except Exception:
  print("startup")
' 2>/dev/null || echo "startup")

# Reset prompt count on every session start so the UserPromptSubmit cadence is clean.
mkdir -p "$STATE_DIR"
echo "0" > "$COUNT_FILE"

# Only inject the recovery payload on compact or resume — startup already loads CLAUDE.md fresh.
if [[ "$SOURCE" != "compact" && "$SOURCE" != "resume" ]]; then
  exit 0
fi

# Read kernel; abort silently if missing.
if [[ ! -f "$KERNEL_PATH" ]]; then
  exit 0
fi

KERNEL_CONTENT=$(<"$KERNEL_PATH")

# PARAMETERIZE — generic default below; replace the bullet(s) with this
# runtime's re-orientation steps.
RECOVERY_REMINDER="## Post-compaction recovery

The session has just resumed after context compaction (source: ${SOURCE}). The conversation history was summarised; rule-level fidelity may have decayed in the summary. CLAUDE.md is re-injected verbatim below — treat it as the floor. Before doing substantive work this turn, re-read the active context/orientation files for this runtime (do not infer state from the summary)."

PAYLOAD="${RECOVERY_REMINDER}

---

${KERNEL_CONTENT}"

# Emit hookSpecificOutput.additionalContext JSON.
python3 - "$PAYLOAD" <<'PY'
import json, sys
payload = sys.argv[1]
out = {
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": payload
  }
}
print(json.dumps(out))
PY

exit 0
