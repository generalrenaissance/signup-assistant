# Signup assistant

Fills in a signup form for you. You press one button at the end.

You do not need to know anything technical. Follow the steps in order.

---

## Part 1 — Set it up (once, about 5 minutes)

### 1. Install Brave

A web browser. The tool needs its own, separate from the one you normally use, so it
never touches your tabs or logins.

Go to **brave.com** → click Download Brave → open the file that downloads → drag the
Brave icon into your Applications folder.

### 2. Install Node.js

The software this tool is built on. It has no window and you will never open it. It
just needs to be there.

Go to **nodejs.org** → click the big green button on the **left**, marked LTS → open
the file that downloads → click Continue, Agree and Install until it finishes. It will
ask for your Mac password. That is normal for an installer.

### 3. Download this tool

Download **SignupAssistant-Mac.zip** from here:

https://github.com/generalrenaissance/signup-assistant/releases/latest

Use that link, not the green Code button — a Code download arrives in a state macOS
will not run.

### 4. Unzip it

Open Downloads and double-click the file you just got. A folder called
**Signup Assistant** appears. Open it.

Drag that folder somewhere you will find it again, like your Documents folder.

### 5. Open it for the first time

Inside is a file called **START HERE.command**.

A normal double-click will **not** work this first time. Apple blocks files downloaded
from the internet and shows a warning. Nothing is wrong.

Do this instead, once:

1. Hold **Control** and click on START HERE.command
2. Choose **Open**
3. A box appears saying macOS cannot verify the developer
4. Click **Open** in that box

A black window opens. That is the tool.

### 6. Fill in your details

The first run creates a file called **identity.json** and tells you to fill it in.

Double-click it — it opens in TextEdit. You will see lines like:

    "company": null,
    "email": null,

Replace each `null` with your own value **in quote marks**:

    "company": "Your Company Ltd",
    "email": "you@yourcompany.com",

Save and close. Setup is done.

---

## Part 2 — Sign up somewhere (about a minute)

1. Double-click **START HERE.command**
2. It asks for a URL. Go to the vendor's signup page in your normal browser, copy the
   address from the bar at the top, paste it in and press return
3. Wait about 30 seconds. A Brave window opens with the whole form already filled in
4. Press the **Sign Up** button in that window
5. If a picture puzzle appears, solve it
6. Look back at the black window — it tells you whether it worked

You never type into the form. You never choose or see the password: one is created for
you and saved to 1Password, or to a file in the folder if you do not have 1Password.

---

## Why you have to press the button

Signup pages check whether a real person is filling the form in. There is no honest way
around that check, and this tool does not use the services that fake it. So that one
press stays with you. Everything else is done for you.

---

## If something goes wrong

| What you see | What to do |
|---|---|
| Nothing happens when you double-click | You skipped the Control-click in step 5 |
| "Brave Browser is not installed" | Part 1, step 1 |
| "Node.js is not installed" | Part 1, step 2 |
| "identity.json still has blanks in it" | Part 1, step 6 |
| The Brave window opens but the form stays empty | That site is not supported yet |
| "a required field has no value" | Add that detail to identity.json |

---

<details>
<summary>Technical notes</summary>

`bash signup.sh <url> --dry` prints the fill plan and types nothing.

`detect_fields.js` matches inputs by label, name, placeholder and autocomplete, then maps
them to identity keys. Checkboxes are never text targets. Where a form has no company
field, a bare "Name" field is treated as the account holder — the company. Per-vendor
overrides live in `vendors/*.json` and are only needed when auto-detection misses.

Exit codes: 0 submitted · 4 no press detected · 5 required field had no value ·
6 the page refused it · 7 could not save the password, nothing submitted.

Known gaps: forms rendered by JavaScript after load (Notion, HubSpot, PlusVibe) detect
nothing yet; the path after the human press has not been exercised end to end.

Not fully automatic because signup pages score the browser: measured across headless,
normal, and a normal browser on a profile with weeks of real history — all refused, and
`grecaptcha.execute()` returned no token at all. No CAPTCHA-solving services are used.
</details>
