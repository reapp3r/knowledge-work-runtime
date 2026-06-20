#!/usr/bin/env bash
# PreToolUse hook for Read|Write|Edit|NotebookEdit|Glob|Grep —
# block paths that resolve outside the runtime + sibling-runtime scope.
#
# Thin wrapper: all scope logic lives in boundary_scope.py (shared with
# bash-boundary.sh — one source of truth). See its docstring for the scope
# definition, including the .git-walk repo-root derivation and the declared
# exceptions (/tmp/**, auto-memory, root-session transcript mining).
#
# Why a hook and not permissions.deny: the broad denies on absolute
# home-tree paths can't see through path resolution — a relative call like
# Read("./cases/foo.md") gets normalised to an absolute path and trips the
# deny even though cwd is in scope. This checks AFTER resolution.
#
# A runtime needing more (e.g. one runtime that may read another privileged
# area) extends the sibling set via CLAUDE_BOUNDARY_EXTRA_SIBLINGS="<name>"
# on the hook command line in that runtime's settings.json.

set -euo pipefail
LIB="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/boundary_scope.py"
exec /usr/bin/env python3 "$LIB" paths
