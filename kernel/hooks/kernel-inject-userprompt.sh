#!/usr/bin/env bash
# UserPromptSubmit hook — re-injects the runtime CLAUDE.md every Nth prompt
# via hookSpecificOutput.additionalContext. Counters mid-session rule decay.
# Pattern: modulo-gated kernel re-injection. Sources CLAUDE.md directly so the
# injected content cannot drift from the always-loaded floor; no separate
# kernel file to maintain.
#
# Install one copy per runtime, under <runtime>/.claude/hooks/<runtime>/.
# Tunable via env: KERNEL_INJECT_FREQUENCY (default 6), KERNEL_INJECT_SUPPRESS_FIRST (default 3).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
KERNEL_PATH="${REPO_ROOT}/CLAUDE.md"
STATE_DIR="${REPO_ROOT}/.scratch/hook-state"
COUNT_FILE="${STATE_DIR}/prompt-count"
FREQUENCY="${KERNEL_INJECT_FREQUENCY:-6}"
SUPPRESS_FIRST="${KERNEL_INJECT_SUPPRESS_FIRST:-3}"

# Read hook input (JSON on stdin) — drained but not used; the hook is stateless beyond the count file.
cat >/dev/null 2>&1 || true

# Initialise / increment prompt count.
mkdir -p "$STATE_DIR"
if [[ -f "$COUNT_FILE" ]]; then
  COUNT=$(<"$COUNT_FILE")
else
  COUNT=0
fi
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNT_FILE"

# Suppress first N prompts (let the session warm up; CLAUDE.md is fresh).
if (( COUNT <= SUPPRESS_FIRST )); then
  exit 0
fi

# Modulo gate.
if (( COUNT % FREQUENCY != 0 )); then
  exit 0
fi

# Read kernel; abort silently if missing.
if [[ ! -f "$KERNEL_PATH" ]]; then
  exit 0
fi

KERNEL_CONTENT=$(<"$KERNEL_PATH")

# Emit hookSpecificOutput.additionalContext JSON. Use python for JSON escaping safety.
python3 - "$KERNEL_CONTENT" <<'PY'
import json, sys
kernel = sys.argv[1]
out = {
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": kernel
  }
}
print(json.dumps(out))
PY

exit 0
