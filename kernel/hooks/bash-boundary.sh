#!/usr/bin/env bash
# PreToolUse hook for Bash — block shell commands referencing paths outside
# the runtime + sibling-runtime scope.
#
# Thin wrapper: all scope logic lives in boundary_scope.py (shared with
# read-boundary.sh — one source of truth). Allowlist model: every absolute,
# ~ or $HOME path token in the command must resolve into scope or under a
# read-only system prefix (/usr, /bin, /opt, /tmp, ...). Absolute in-repo
# paths are permitted; /etc, /var and the home tree outside the repo stay
# blocked.
#
# GUARDRAIL, NOT A BOUNDARY — see boundary_scope.py § KNOWN LIMITATION. A
# pre-execution lexer cannot see a path constructed at runtime. Pair this with
# Claude Code's native OS sandbox for kernel-enforced isolation.

set -euo pipefail
LIB="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/boundary_scope.py"
exec /usr/bin/env python3 "$LIB" bash
