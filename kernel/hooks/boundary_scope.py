#!/usr/bin/env python3
"""Shared scope resolver for the boundary PreToolUse hooks.

Single source of truth for what is in scope, consumed by read-boundary.sh
(path-bearing tools) and bash-boundary.sh (shell commands). Reads the
PreToolUse JSON envelope on stdin; exits 0 (allow) or 2 (deny, reason on
stderr).

Scope:
  - own runtime:           $CLAUDE_PROJECT_DIR/**
  - sibling runtimes:      <repo-root>/{SIBLINGS}/**
                           (+ CLAUDE_BOUNDARY_EXTRA_SIBLINGS, comma/space list)
  - repo-root pinpoints:   <repo-root>/{CLAUDE.md,README.md,.gitignore}
  - system temp:           /tmp/** (Claude Code writes background-task output
                           under /tmp/claude-<uid>/...; scratch probes live here)
  - auto-memory:           ~/.claude/projects/<project-key>*/memory/**
  - root maintenance:      when launched from the repo root itself, the whole
                           ~/.claude/projects/<project-key>* family (transcript
                           mining for /retro)

<repo-root> is found by walking up from $CLAUDE_PROJECT_DIR to the nearest
directory containing .git — never dirname(), which leaked ~/.claude into
scope when launching from the repo root (parent = $HOME).

PARAMETERIZE: SIBLINGS is the cross-runtime read-set — the runtime directories
any session may read, plus the root ".claude" shared layer. Omit privileged
runtimes (e.g. an orchestrator "workspace" that holds distilled/confidential
work) so they are readable from themselves but not a universal read target.

Bash mode lexes the command with a shell-aware tokenizer (shlex with
punctuation_chars, so quotes are respected and operators split out), then
checks only the tokens that are genuine path operands — absolute, ~, $HOME,
or any relative token containing a `..` segment that could climb out of cwd.
String data (commit messages, grep/sed/regex patterns, globbed args) is left
alone, because a quoted multi-word argument or an in-cwd relative path is not
a boundary-crossing reference.

KNOWN LIMITATION — bash mode is a guardrail against *accidental* out-of-scope
references, not a security boundary against *intent*. No pre-execution lexer
can see a path that the command constructs at runtime: `bash /tmp/s.sh`,
`cat "$VAR"`, `$(printf /et''c/x)`, base64-decoded paths, child processes.
Closing those requires the command to run inside an OS sandbox (mount
namespace / bwrap / macOS Seatbelt) where the kernel — not this script —
enforces the boundary. Treat a green result here as "no obvious accidental
escape", not "command is safe". Pair this hook with Claude Code's native
sandbox (sandbox.enabled: true) for the kernel-enforced boundary.
"""

import json
import os
import re
import shlex
import sys

# PARAMETERIZE — the cross-runtime read-set (runtime dirs + the root shared layer).
SIBLINGS = ["workspace", "data", "reference", "tools", ".claude"]
PINPOINTS = ("CLAUDE.md", "README.md", ".gitignore")
# Read-only OS infrastructure a shell command legitimately references.
# /etc, /var, /home (outside the repo) stay out deliberately.
SYSTEM_PREFIXES = (
    "/usr/", "/bin/", "/sbin/", "/lib/", "/lib64/", "/opt/", "/snap/",
    "/dev/", "/proc/", "/sys/", "/run/user/", "/tmp/",
)
SYSTEM_EXACT = ("/bin", "/usr", "/dev/null", "/dev/stdin", "/dev/stdout",
                "/dev/stderr", "/tmp")
# /tmp is a symlink to /private/tmp on macOS; realpath() rewrites every /tmp
# path to its canonical target, so match both the symlink and what it resolves
# to (on Linux the set collapses to just "/tmp").
TMP_ROOTS = tuple({"/tmp", os.path.realpath("/tmp")})

# Legacy fallback tokenizer (only used when shlex can't parse the command,
# e.g. unbalanced quotes). Absolute, ~ or $HOME path tokens; lookbehind skips
# mid-word slashes. Kept so a parse failure degrades to the prior behaviour
# rather than failing open.
TOKEN_RE = re.compile(r"(?<![\w.])(?:\$HOME|~|/)[A-Za-z0-9_.~+@%/-]*")
URL_RE = re.compile(r"[a-zA-Z][a-zA-Z0-9+.-]*://[^\s'\"]+")

# Strip a leading shell redirection operator glued to a path ("2>/etc/x",
# ">>/tmp/log") so the path behind it is classified, not the operator.
REDIR_PREFIX_RE = re.compile(r"^[0-9]*(?:>>|<<|>|<)&?")
# flag=value / NAME=value assignments — the path of interest is the value.
ASSIGN_RE = re.compile(r"^(?:-{1,2}[A-Za-z0-9][\w.-]*|[A-Za-z_][\w.]*)=(.+)$")
# A relative token that climbs out of cwd via a `..` segment.
DOTDOT_RE = re.compile(r"(?:^|/)\.\.(?:/|$)")


def under(child, parent):
    return child == parent or child.startswith(parent + os.sep)


def _looks_like_path(p):
    """True if p is a boundary-crossing path reference: absolute, home-rooted,
    or a relative path with a `..` segment that could climb out of cwd. Plain
    relative paths (no `..`) resolve inside cwd — in scope by construction —
    and are deliberately not flagged."""
    if not p:
        return False
    if p.startswith("/") or p.startswith("~") or p.startswith("$HOME"):
        return True
    return bool(DOTDOT_RE.search(p))


def _candidates_from_token(tok):
    """Path strings to authorize from one lexed shell token. Empty for
    operators, flags, string data, and in-cwd relative paths."""
    if not tok or any(c.isspace() for c in tok):
        # Whitespace ⇒ a quoted multi-word argument (a message, a pattern):
        # data, not a path operand.
        return []
    tok = REDIR_PREFIX_RE.sub("", tok)
    if not tok:
        return []
    m = ASSIGN_RE.match(tok)
    raw = m.group(1).split(":") if m else [tok]
    return [p for p in raw if _looks_like_path(p)]


def bash_path_tokens(command):
    """Lex a shell command and return the path operands to authorize.

    Uses shlex with punctuation_chars so quotes are honoured (regex/sed
    patterns stay intact) and operators (;|&<>()) split into their own tokens
    (so `cmd;/etc/x` exposes the path). Falls back to the legacy regex on a
    parse error so malformed input never does worse than the prior hook."""
    try:
        lex = shlex.shlex(command, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        tokens = list(lex)
    except ValueError:
        stripped = URL_RE.sub(" ", command)
        out = []
        for t in TOKEN_RE.findall(stripped):
            if t.startswith("~") or re.search(r"[A-Za-z]", t):
                out.append(t)
        return out
    out = []
    for tok in tokens:
        out.extend(_candidates_from_token(tok))
    return out


def repo_root_of(proj):
    root = proj
    while not os.path.isdir(os.path.join(root, ".git")):
        parent = os.path.dirname(root)
        if parent == root:
            return proj  # no .git anywhere — degrade to project dir
        root = parent
    return root


def project_key(repo_root):
    return repo_root.replace(os.sep, "-")


class Scope:
    def __init__(self):
        proj = os.environ.get("CLAUDE_PROJECT_DIR", "") or os.getcwd()
        self.proj = os.path.realpath(proj)
        self.repo = repo_root_of(self.proj)
        extra = os.environ.get("CLAUDE_BOUNDARY_EXTRA_SIBLINGS", "")
        self.siblings = SIBLINGS + [s for s in extra.replace(",", " ").split() if s]
        home = os.path.expanduser("~")
        self.projects_dir = os.path.join(home, ".claude", "projects")
        self.key = project_key(self.repo)

    def resolve(self, raw):
        expanded = os.path.expanduser(raw.replace("$HOME", "~", 1) if raw.startswith("$HOME") else raw)
        if not os.path.isabs(expanded):
            expanded = os.path.join(os.getcwd(), expanded)
        resolved = os.path.realpath(os.path.abspath(expanded))
        # posixpath preserves exactly-two leading slashes ("//home") — collapse,
        # or "//home/..." would dodge every startswith("/home/...") check.
        return re.sub(r"^/+", "/", resolved)

    def harness_family(self, target):
        """~/.claude/projects/<key>*/ paths: memory always; everything when
        the session runs from the repo root (maintenance / retro mining)."""
        if not under(target, self.projects_dir):
            return False
        rel = os.path.relpath(target, self.projects_dir)
        top = rel.split(os.sep, 1)[0]
        if not top.startswith(self.key):
            return False
        if self.proj == self.repo:
            return True
        parts = rel.split(os.sep)
        return len(parts) >= 2 and parts[1] == "memory"

    def allows_path(self, target):
        if under(target, self.proj):
            return True
        for sibling in self.siblings:
            if under(target, os.path.realpath(os.path.join(self.repo, sibling))):
                return True
        for leaf in PINPOINTS:
            if target == os.path.realpath(os.path.join(self.repo, leaf)):
                return True
        if any(under(target, t) for t in TMP_ROOTS):
            return True
        if self.harness_family(target):
            return True
        return False

    def allows_bash_token(self, token):
        if token in SYSTEM_EXACT:
            return True
        resolved = self.resolve(token)
        if resolved in SYSTEM_EXACT:
            return True
        for prefix in SYSTEM_PREFIXES:
            if resolved.startswith(prefix):
                return True
        return self.allows_path(resolved)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "paths"
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0  # malformed envelope — never wedge the session on our own bug

    scope = Scope()
    tool = payload.get("tool_name", "")
    tool_input = payload.get("tool_input") or {}

    if mode == "paths":
        if tool in ("Read", "Write", "Edit"):
            target = tool_input.get("file_path", "")
        elif tool == "NotebookEdit":
            target = tool_input.get("notebook_path", "")
        elif tool in ("Glob", "Grep"):
            target = tool_input.get("path", "")
        else:
            return 0
        if not target:
            return 0
        resolved = scope.resolve(target)
        if scope.allows_path(resolved):
            return 0
        sys.stderr.write(
            f"read-boundary: path '{resolved}' resolves outside the runtime + sibling scope.\n"
            "Scope: $CLAUDE_PROJECT_DIR/**, repo-root/{<siblings>}/**, "
            "repo-root/{CLAUDE.md,README.md,.gitignore}, /tmp/**, "
            "~/.claude/projects/<project>*/memory/**.\n"
        )
        return 2

    if mode == "bash":
        command = tool_input.get("command", "")
        if not command:
            return 0
        # Substitute the real project dir (not empty) so "$CLAUDE_PROJECT_DIR/x"
        # resolves in-scope instead of becoming a bare "/x".
        command = command.replace("${CLAUDE_PROJECT_DIR}", scope.proj).replace("$CLAUDE_PROJECT_DIR", scope.proj)
        for token in bash_path_tokens(command):
            if not scope.allows_bash_token(token):
                sys.stderr.write(
                    f"bash-boundary: '{token}' resolves outside the runtime + sibling scope. "
                    "Use in-repo paths; /tmp/** and ~/.claude/projects/<project>*/memory/** are allowed.\n"
                )
                return 2
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
