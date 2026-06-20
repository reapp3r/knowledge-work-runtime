#!/usr/bin/env bash
# PreCompact hook — save context state before compaction so post-compact we land
# cleanly. Writes to <runtime>/.scratch/hook-state/pre-compact-state.md (scratch,
# gitignored). Generic recovery aid, not a domain artefact. Post-compact,
# kernel-inject-sessionstart.sh re-injects CLAUDE.md; this dump preserves the
# hook-input snapshot for context.
#
# Install one copy per runtime, under <runtime>/.claude/hooks/<runtime>/.

set -euo pipefail

# Read hook input (JSON on stdin) — best-effort preserve.
INPUT=$(cat || true)

# Self-locate the runtime root from the script path — never from cwd or
# CLAUDE_PROJECT_DIR (both vary with the launch directory).
HOOK_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
RUNTIME_ROOT="$(cd "$HOOK_DIR/../../.." && pwd)"

DUMP_PATH="${RUNTIME_ROOT}/.scratch/hook-state/pre-compact-state.md"
DUMP_DIR=$(dirname "$DUMP_PATH")

mkdir -p "$DUMP_DIR"

{
  echo "---"
  echo "name: pre-compact-state-dump"
  echo "description: Auto-written by PreCompact hook before context compaction. Local recovery aid; not canonical."
  echo "metadata:"
  echo "  type: reference"
  echo "compacted_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "---"
  echo
  echo "# Pre-compact state dump"
  echo
  echo "Auto-saved before context compaction. Post-compact, re-orient via this runtime's active context files. This dump preserves the hook-input snapshot — it is *not* a substitute for the kernel re-inject (handled by kernel-inject-sessionstart.sh on resume)."
  echo
  echo "## Hook input snapshot"
  echo
  echo "\`\`\`"
  echo "$INPUT" | head -100
  echo "\`\`\`"
} > "$DUMP_PATH" 2>/dev/null || true

# Always exit 0 — never block compaction. State dump is best-effort.
exit 0
