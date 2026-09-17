#!/usr/bin/env bash
# Prints ok / MISSING for every setup step in README.md and names the section that fixes it.
# The first run may take a minute: `uv run` installs the pinned Python and modal client.
cd "$(dirname "$0")/.."
fail=0
PY=$(command -v python3 || command -v python)   # python3 on macOS, often just python on Windows
ok()   { printf 'ok       %s\n' "$1"; }
miss() { printf 'MISSING  %-38s -> %s\n' "$1" "$2"; fail=1; }
todo() { printf 'todo     %-38s -> %s\n' "$1" "$2"; }   # not your job yet
note() { printf '         %s\n' "$1"; }

# --- right directory? ---
for f in main.py pyproject.toml uv.lock .python-version; do
  [ -f "$f" ] && ok "$f" || miss "$f not found" "run this from the repo root"
done

# --- tools (§2) ---
if command -v uv >/dev/null 2>&1; then ok "uv ($(uv --version 2>/dev/null | awk '{print $2}'))"
else miss "uv" "§2 Tools — brew install uv"; fi
command -v git >/dev/null 2>&1 && ok "git" || todo "git" "Appendix B"

# Everything below shells out through uv, so stop here if it's missing.
command -v uv >/dev/null 2>&1 || { echo "fix the MISSING lines, then re-run"; exit 1; }

# --- the modal client (§2) ---
MODAL_V=$(uv run -q modal --version 2>/dev/null | tr -d '\r')
if [ -n "$MODAL_V" ]; then ok "modal client ($MODAL_V)"
else
  miss "modal client won't run" "§2 — uv sync, then read the error it prints"
  echo "fix the MISSING lines, then re-run"; exit 1
fi

# --- auth (§3) ---
HAVE_TOKEN=1
if [ -n "$MODAL_TOKEN_ID" ] && [ -n "$MODAL_TOKEN_SECRET" ]; then
  ok "token (from MODAL_TOKEN_ID / MODAL_TOKEN_SECRET)"
elif [ -f "$HOME/.modal.toml" ]; then
  ok "token file (~/.modal.toml)"
else
  HAVE_TOKEN=0
  miss "no Modal token" "§3 — uv run modal setup"
fi

# Nothing past here can work without a token, and guessing would only add noise.
if [ "$HAVE_TOKEN" = 0 ]; then
  todo "workspace + deploy checks skipped" "§3 first, then re-run"
  echo "fix the MISSING lines, then re-run"
  exit 1
fi

# --- which workspace does this machine's token belong to? (§3, and the §5 trap) ---
WS=$(uv run -q modal profile list --json 2>/dev/null | "$PY" -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
rows = d if isinstance(d, list) else (d.get("profiles") or d.get("data") or d)
if isinstance(rows, dict):
    rows = [dict(v, profile=k) for k, v in rows.items() if isinstance(v, dict)]
rows = [r for r in rows if isinstance(r, dict)]
def active(r):
    for k in ("active", "is_active", "current"):
        v = r.get(k)
        if v is True or str(v).strip().lower() in ("true", "yes", "*", "active"):
            return True
    return False
pick = [r for r in rows if active(r)] or rows
if not pick:
    sys.exit(1)
r = pick[0]
for k in ("workspace", "workspace_name", "name", "profile"):
    if r.get(k):
        print(r[k]); break
' 2>/dev/null | tr -d '\r')

if [ -n "$WS" ]; then
  ok "active workspace ($WS)"
  note "now open https://modal.com/apps with no path — if the browser lands in a"
  note "workspace other than '$WS', that mismatch is §5, not a broken run."
else
  todo "couldn't parse the workspace name" "§3 — eyeball it yourself:"
  uv run -q modal profile list 2>&1 | sed 's/^/         /'
fi

# --- does the token actually authenticate? ---
APPS=$(uv run -q modal app list 2>&1)
if [ $? -eq 0 ]; then
  ok "Modal accepted the token"
  echo "$APPS" | grep -q 'example-get-started' \
    && ok "example-get-started is deployed" \
    || todo "nothing deployed yet" "§6 — uv run modal deploy main.py"
else
  miss "couldn't reach Modal (offline, or token rejected)" "§3 — re-run uv run modal setup"
  echo "$APPS" | tail -3 | sed 's/^/         /'
fi

# --- informational: the version that will be mirrored into the container (§4, troubleshooting) ---
PIN=$(tr -d '[:space:]' < .python-version 2>/dev/null)
[ -n "$PIN" ] && note "this repo pins Python $PIN; Modal mirrors your local minor version remotely"

[ $fail = 0 ] && echo "all set — go to §4" || echo "fix the MISSING lines, then re-run"
exit $fail
