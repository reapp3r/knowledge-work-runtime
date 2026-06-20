#!/usr/bin/env bash
# PreToolUse hook for Write|Edit|NotebookEdit — area content is owned by its
# runtime. Each owned area is writable only in its own session; a CURATED area
# (e.g. "reference") is writable only via its curator subagent's writes. A root
# session may still maintain any area's operational surfaces: <area>/.claude/**,
# <area>/CLAUDE.md, <area>/README.md.
#
# Wired in the ROOT settings.json. Generic by design: if wired into a runtime's
# settings.json, that runtime keeps full write access to its own area and is
# gated on the others. (Wiring it into a runtime that legitimately writes a
# sibling area — e.g. an ingest skill symlinked into the orchestrator that
# writes the data area — would break that pathway; keep it at root.)
#
# PARAMETERIZE: the AREAS map below — which runtime dirs are write-gated, the
# message shown on denial, and which (if any) are curator-subagent-only.

set -euo pipefail

payload="$(cat || true)"
[[ -z "$payload" ]] && exit 0

tool_name=$(printf '%s' "$payload" | /usr/bin/jq -r '.tool_name // ""')

case "$tool_name" in
  Write|Edit)
    target=$(printf '%s' "$payload" | /usr/bin/jq -r '.tool_input.file_path // ""')
    ;;
  NotebookEdit)
    target=$(printf '%s' "$payload" | /usr/bin/jq -r '.tool_input.notebook_path // ""')
    ;;
  *)
    exit 0
    ;;
esac

[[ -z "$target" ]] && exit 0

transcript=$(printf '%s' "$payload" | /usr/bin/jq -r '.transcript_path // ""')

verdict=$(CLAUDE_TARGET="$target" CLAUDE_PROJ="${CLAUDE_PROJECT_DIR:-}" \
          CLAUDE_TRANSCRIPT="$transcript" /usr/bin/env python3 - <<'PY'
import os, sys

target     = os.environ.get("CLAUDE_TARGET", "")
proj       = os.environ.get("CLAUDE_PROJ", "") or os.getcwd()
transcript = os.environ.get("CLAUDE_TRANSCRIPT", "")

target_expanded = os.path.expanduser(target)
if not os.path.isabs(target_expanded):
    target_abs = os.path.abspath(os.path.join(os.getcwd(), target_expanded))
else:
    target_abs = os.path.abspath(target_expanded)
target_abs = os.path.realpath(target_abs)

proj_abs = os.path.realpath(proj)

# repo root = nearest ancestor of the project dir (inclusive) containing .git
repo_root = proj_abs
while not os.path.isdir(os.path.join(repo_root, ".git")):
    parent = os.path.dirname(repo_root)
    if parent == repo_root:
        repo_root = proj_abs  # no .git found — fall back, gate degrades open
        break
    repo_root = parent

def under(child, parent):
    return child == parent or child.startswith(parent + os.sep)

is_subagent = "/subagents/" in transcript

# PARAMETERIZE — owned areas. Own-session-only areas have curator=False; a
# curated area (curator=True) additionally allows writes from any subagent
# session (the curator agent pathway, detected by /subagents/ in the transcript).
AREAS = {
    "workspace": ("workspace is writable only in workspace/ sessions (the orchestrator runtime).", False),
    "data":      ("data is writable only in data/ sessions (the pipeline-operator runtime).", False),
    "reference": ("reference content writes go through the curator — dispatch the reference curator agent (its writes pass this gate).", True),
}

for area, (msg, curator) in AREAS.items():
    area_root = os.path.realpath(os.path.join(repo_root, area))
    if not under(target_abs, area_root):
        continue
    if proj_abs == area_root:                      # own-runtime session
        print("OK"); sys.exit(0)
    if proj_abs == repo_root:                      # root maintenance surfaces
        if under(target_abs, os.path.join(area_root, ".claude")) or \
           target_abs in (os.path.join(area_root, "CLAUDE.md"),
                          os.path.join(area_root, "README.md")):
            print("OK"); sys.exit(0)
    if curator and is_subagent:                    # curator pathway
        print("OK"); sys.exit(0)
    print("DENY"); print(target_abs); print(msg); sys.exit(0)

print("OK")
sys.exit(0)
PY
)

if [[ "${verdict%%$'\n'*}" == "OK" ]]; then
  exit 0
fi

abs_path=$(printf '%s\n' "$verdict" | /usr/bin/sed -n '2p')
reason=$(printf '%s\n' "$verdict" | /usr/bin/sed -n '3p')
{
  echo "area-write-gate: '$abs_path' — $reason"
  echo "Root sessions may edit <area>/.claude/**, <area>/CLAUDE.md, <area>/README.md (maintenance surfaces)."
} >&2
exit 2
