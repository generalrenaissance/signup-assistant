#!/bin/bash
# signup.sh — the ONE command for a cold signup.
# CREATED BY CLAUDE (Claude Code, David's assistant), 2026-08-14 (ET).
# WHAT: opens a REAL Brave window on its own profile, fills the whole signup form from
#       code/js/identity.json, generates the password, then waits. David clicks ONLY the
#       bot-check. The script detects the token and finishes the submit.
# WHY:  anti-bot challenges score the browser, not the typing — measured across 3 browser
#       configurations 2026-08-14, all rejected. See memory/reference_why_signups_fail.md.
#       We do NOT use CAPTCHA solver farms.
# UNDO: pkill -f signup-profile   (nothing else persists; password goes to 1Password)
#
# Usage:  bash code/js/signup.sh <signup-url> [--dry]
set -uo pipefail
URL="${1:-}"; DRY="${2:-}"
[ -z "$URL" ] && { echo "usage: bash code/js/signup.sh <signup-url> [--dry]"; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# A double-clicked .command gets a login-shell PATH, but being run any other way does not.
# Without this, `op` at ~/.local/bin is invisible and the password silently takes the
# file fallback on a machine where 1Password was available all along.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export NODE_PATH="$ROOT/node_modules"
BRAVE="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
PROFILE="$HOME/.brave-signup-profile"; PORT=9355
export SIGNUP_PORT=$PORT
mkdir -p "$PROFILE"

pkill -f "brave-signup-profile" 2>/dev/null; sleep 1
"$BRAVE" --remote-debugging-port=$PORT --user-data-dir="$PROFILE" \
  --no-first-run --no-default-browser-check --new-window \
  --remote-allow-origins=http://localhost:$PORT about:blank >/dev/null 2>&1 &
for i in $(seq 1 40); do
  curl -s "http://localhost:$PORT/json/version" >/dev/null 2>&1 && break; sleep 0.5
done
curl -s "http://localhost:$PORT/json/version" >/dev/null 2>&1 || { echo "ERROR: browser did not start"; exit 1; }

# The profile RESTORES its previous tabs on launch — 5 stale signup tabs piled up on
# 2026-08-14 and made it impossible to tell which window to use. Prune to one.
for id in $(curl -s "http://localhost:$PORT/json" | sed -n 's/.*"id": "\([A-F0-9]*\)".*/\1/p' | tail -n +2); do
  curl -s "http://localhost:$PORT/json/close/$id" >/dev/null 2>&1 || true
done

# password: generated here, passed only by env, never argv, never printed
export SIGNUP_PW="$(python3 -c "import secrets,string;a=string.ascii_letters+string.digits+'!@#%^*-_';print(''.join(secrets.choice(a) for _ in range(24)))")"

# STORE IT FIRST. A password that only exists in this shell is one failed submit away
# from an account nobody can log into. Written to 1Password BEFORE the signup runs.
HOST="$(printf '%s' "$URL" | sed -E 's|https?://||; s|/.*||; s|^www\.||')"
ITEM="signup: ${HOST} (david-Claude Code)"
STORED=""
if [ "$DRY" != "--dry" ]; then
  if command -v op >/dev/null 2>&1; then
    if op item get "$ITEM" --vault "API Secret Keys" >/dev/null 2>&1; then
      op item edit "$ITEM" --vault "API Secret Keys" "password=$SIGNUP_PW" >/dev/null 2>&1 && STORED="1Password"
    else
      op item create --category Login --vault "API Secret Keys" --title "$ITEM" \
        "username=$(python3 -c "import json;print(json.load(open('$HERE/identity.json'))['email'])")" \
        "password=$SIGNUP_PW" "owner[text]=david-Claude Code" "created_by[text]=david-Claude Code" \
        "notesPlain=CREATED BY CLAUDE (Claude Code, David's assistant), $(TZ=America/New_York date '+%Y-%m-%d %H:%M ET').
WHAT: login for ${HOST}, created by the signup assistant.
HOW: password generated locally, stored here BEFORE the form was submitted.
REVOKE: delete the account at ${HOST}, then delete this item." >/dev/null 2>&1 && STORED="1Password"
    fi
  fi
  # FALLBACK. Never proceed with a password that exists nowhere: without 1Password on this
  # machine the old code skipped storage SILENTLY, and a successful signup would have created
  # an account whose password nobody could ever recover.
  if [ -z "$STORED" ]; then
    PWFILE="$HERE/PASSWORD - ${HOST}.txt"
    ( umask 077; printf 'Signup: %s\nUser:   %s\nPassword below. Put it in 1Password, then delete this file.\n\n%s\n' \
        "$HOST" "$(python3 -c "import json;print(json.load(open('$HERE/identity.json'))['email'])")" "$SIGNUP_PW" > "$PWFILE" )
    if [ -f "$PWFILE" ]; then
      STORED="file"
      echo
      echo "  ###############################################################"
      echo "  #  1Password is not set up on this Mac, so the password was"
      echo "  #  saved to a file instead:"
      echo "  #"
      echo "  #    $PWFILE"
      echo "  #"
      echo "  #  Move it into 1Password and delete that file when you are done."
      echo "  ###############################################################"
      echo
    else
      echo "  STOPPING: could not save the password anywhere. Nothing was submitted."
      exit 7
    fi
  else
    echo "  Password saved to 1Password as \"$ITEM\""
  fi
fi

if [ "$DRY" = "--dry" ]; then
  node "$ROOT/signup_assist.js" --auto "$URL" --dry; rc=$?
  pkill -f "brave-signup-profile" 2>/dev/null
  exit $rc
fi

echo "────────────────────────────────────────────────────────"
echo " A Brave window is opening and filling itself in."
echo " When it stops filling, press the Sign Up button in it."
echo " If a picture puzzle appears, solve it. Do not type in the form.
 You have 10 minutes."
echo "────────────────────────────────────────────────────────"
osascript -e 'tell application "Brave Browser" to activate' 2>/dev/null
node "$ROOT/signup_assist.js" --auto "$URL"; rc=$?
case $rc in
  0) echo "DONE — submitted. Password is being stored in 1Password." ;;
  4) echo "TIMED OUT — no click detected inside the window." ;;
  5) echo "STOPPED — a required field has no value in identity.json. Nothing was typed." ;;
  *) echo "FAILED (exit $rc)." ;;
esac
exit $rc
