#!/bin/bash
# install.sh — one command to make a Mac ready to run signups.
# CREATED BY CLAUDE (Claude Code, David's assistant), 2026-08-14 (ET).
# Run:  bash install.sh          (sets itself up under ~/signup-assistant)
# Undo: delete the ~/signup-assistant folder in Finder. Nothing else is installed.
set -uo pipefail
DEST="$HOME/signup-assistant"
REPO="https://github.com/generalrenaissance/signup-assistant.git"

say(){ printf '  %s\n' "$*"; }
echo "Signup assistant — setup"

# 1. prerequisites, named in plain English rather than a stack trace
command -v node >/dev/null 2>&1 || { say "MISSING: Node.js. Install from https://nodejs.org (LTS), then run this again."; exit 1; }
command -v git  >/dev/null 2>&1 || { say "MISSING: git. Open Terminal and run: xcode-select --install"; exit 1; }
[ -d "/Applications/Brave Browser.app" ] || { say "MISSING: Brave Browser. Install from https://brave.com, then run this again."; exit 1; }
say "Node $(node -v), git and Brave found."

# 2. get (or refresh) the code
if [ -d "$DEST/.git" ]; then
  say "Updating existing copy in $DEST"
  git -C "$DEST" fetch --quiet origin && git -C "$DEST" checkout --quiet main \
    && git -C "$DEST" pull --quiet --ff-only origin main || { say "Could not update. Ask Claude."; exit 1; }
else
  say "Downloading to $DEST"
  # This repo is PRIVATE and there is no shareable credential for it: the working copy
  # on David's Mac only pushes because its remote URL has a token baked in, which is not
  # something to hand around. VERIFIED 2026-08-14: a fresh clone fails even with the
  # stored helper. So anyone without their OWN GitHub access must use the zip.
  if ! git clone --quiet --depth 1 --filter=blob:none "$REPO" "$DEST" 2>/dev/null; then
    say "This Mac has no GitHub access to the private repo, so there is nothing to download here."
    say ""
    say "Use the zip instead:"
    say "  https://drive.google.com/file/d/1TGo0Ysl-G66Cs8LbTzbBddsDFowsdF3w/view"
    say ""
    say "It contains everything and needs no GitHub account."
    exit 1
  fi
fi

# 3. dependencies
say "Installing dependencies (about 20 seconds)"
( cd "$DEST" && npm install --silent --no-audit --no-fund ) || { say "npm install failed. Ask Claude."; exit 1; }

# 3b. first run has no identity file — create it from the example and say so
if [ ! -f "$DEST/identity.json" ]; then
  cp "$DEST/identity.example.json" "$DEST/identity.json"
  say "Created identity.json from the example."
  say "Open it and fill in your company name, email and phone before the first real run."
fi

# 4. self-test: a dry run types nothing and submits nothing
say "Checking it works..."
OUT="$(cd "$DEST" && bash signup.sh "https://www.track1099.com/signup" --dry 2>&1)"
if printf '%s' "$OUT" | grep -q '"stage": "PLAN"'; then
  say "READY."
  echo
  echo "  To sign up somewhere:"
  echo "    cd ~/signup-assistant/signup"
  echo "    bash signup.sh <the signup page URL>"
  echo
  echo "  A Brave window opens with the form filled in. Press Sign Up in it."
  echo "  Add --dry to see what it would type, without typing anything."
else
  say "Self-test did not pass — output below. Ask Claude."
  printf '%s\n' "$OUT" | tail -5
  exit 1
fi
