# Signup assistant

Fills in a vendor signup form for you. A person presses one button at the end.

It is not fully automatic and cannot be: signup pages score the browser to decide
whether a human is filling the form. Measured across three browser configurations —
headless, normal, and a normal browser on a profile with weeks of real history — all
three were refused before anything was submitted, and `grecaptcha.execute()` returned
no token at all. This project does not use CAPTCHA-solving services. So the tool does
the tedious 95% and leaves the press to a person.

## Setup

Requires **Node.js** and **Brave**, both free.

```bash
git clone https://github.com/generalrenaissance/signup-assistant.git
cd signup-assistant
npm install
cp identity.example.json identity.json     # then fill in your details
```

Or run `bash install.sh`, which does all of that and self-tests.

## Use

```bash
bash signup.sh https://example.com/signup --dry   # shows what it would type; types nothing
bash signup.sh https://example.com/signup         # the real thing
```

A Brave window opens on a profile of its own and fills the form. When it stops,
press the signup button in that window and solve a puzzle if one appears. The
terminal then tells you whether the page accepted or refused it.

## identity.json

Your details, filled into every form. No secrets — the password is generated per
signup and written to 1Password, or to a local file if the 1Password CLI is absent.

A `null` value means "we don't have this". If a form requires one, the tool STOPS
rather than inventing it.

## How it reads a form

`detect_fields.js` matches each visible input by label, name, placeholder and
autocomplete attribute, then maps it to an identity key. Checkboxes are never text
targets. Where a form has no company field, a bare "Name" field is treated as the
account holder — the company — rather than a person.

Per-vendor overrides live in `vendors/*.json` and are only needed when auto-detection
misses.

## Known gaps

- Forms rendered by JavaScript after load (Notion, HubSpot, PlusVibe) detect nothing yet.
- The path after the human press has not been exercised end to end.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Submitted |
| 4 | Timed out — no press detected |
| 5 | Stopped — a required field had no value |
| 6 | The page refused the signup |
| 7 | Could not save the password anywhere; nothing was submitted |
