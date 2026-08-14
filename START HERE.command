#!/bin/bash
# Double-click this. It sets itself up the first time, then asks for a signup page.
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
echo "Signup assistant"; echo

if [ ! -d "/Applications/Brave Browser.app" ]; then
  echo "  Brave Browser is not installed."
  echo "  Get it free from https://brave.com, then run this again."
  echo; read -p "Press return to close."; exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "  Node.js is not installed."
  echo "  Get it free from https://nodejs.org — the big green LTS button on the left."
  echo "  Then run this again."
  echo; read -p "Press return to close."; exit 1
fi

if [ ! -d node_modules ]; then
  echo "  First run — setting up. This takes about 20 seconds."
  npm install --silent --no-audit --no-fund || {
    echo "  Setup failed. Check your internet connection and try again."
    read -p "Press return to close."; exit 1; }
  echo "  Ready."; echo
fi

if [ ! -f identity.json ]; then
  cp identity.example.json identity.json
  echo "  ###############################################################"
  echo "  #  Before the first signup, open this file and fill it in:"
  echo "  #"
  echo "  #    $(pwd)/identity.json"
  echo "  #"
  echo "  #  It needs your company name, email and phone. Double-click it"
  echo "  #  to open it in TextEdit. Replace each null with your value,"
  echo "  #  keeping the quote marks. Save, then run this again."
  echo "  ###############################################################"
  echo; read -p "Press return to close."; exit 1
fi
if grep -q '"company": null' identity.json 2>/dev/null; then
  echo "  identity.json still has blanks in it. Open it, fill in your company"
  echo "  name, email and phone, save, then run this again:"
  echo "    $(pwd)/identity.json"
  echo; read -p "Press return to close."; exit 1
fi

echo "Paste the address of the signup page, then press return."
echo "(example: https://www.track1099.com/signup)"; echo
read -p "URL: " URL
[ -z "$URL" ] && { echo "Nothing entered."; read -p "Press return to close."; exit 1; }
bash signup.sh "$URL"
echo; read -p "Finished. Press return to close."
