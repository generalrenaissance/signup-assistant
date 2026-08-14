#!/usr/bin/env node
/**
 * signup_assist.js — cold-signup assistant.
 *
 * CREATED BY CLAUDE (Claude Code, David's assistant), 2026-08-14 (ET).
 * WHAT: drives a cold vendor signup to completion with ONE human click.
 *   I do: open a real browser, fill every field, set the password, accept terms,
 *          then WAIT. A human clicks only the bot-challenge. I detect the token
 *          landing and finish the submit + the email-verification loop.
 * WHY:  anti-bot challenges (reCAPTCHA v2/v3, Turnstile) score the browser, not the
 *       typing. Measured 2026-08-14 across 3 browser configurations — all rejected.
 *       See memory/reference_why_signups_fail.md. We do NOT use solver farms.
 * UNDO: nothing persistent; kill the browser (pkill -f signup-assist-profile).
 *
 * Usage: node signup_assist.js <vendor.json>   (see vendors/ for the shape)
 */
const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');
const { classify, SCRAPE, TEXTUAL } = require(path.join(__dirname, 'detect_fields.js'));
const s = ms => new Promise(r => setTimeout(r, ms));

const CHALLENGE_FIELDS = ['g-recaptcha-response','recaptcha_token','cf-turnstile-response','h-captcha-response'];

async function challengeSatisfied(page) {
  return page.evaluate(names => names.some(n => {
    const e = document.querySelector(`[name="${n}"]`);
    return e && (e.value || '').length > 30;
  }), CHALLENGE_FIELDS);
}

async function humanType(page, sel, val) {
  await page.click(sel);
  await s(300 + Math.random() * 500);
  for (const c of val) {
    await page.keyboard.type(c, { delay: 65 + Math.floor(Math.random() * 120) });
    if (Math.random() < 0.06) await s(250 + Math.random() * 600);
  }
  await s(500 + Math.random() * 700);
}

// --auto: read ANY signup form and map it to identity.json. No per-vendor config needed.
async function autoPlan(p) {
  const idPath = path.join(__dirname, 'identity.json');
  if (!fs.existsSync(idPath)) {
    console.log(JSON.stringify({ stage: 'STOP', why:
      'identity.json is missing. Copy identity.example.json to identity.json and fill in your details.' }));
    process.exit(5);
  }
  const id = JSON.parse(fs.readFileSync(idPath, 'utf8'));
  const fields = (await p.evaluate(SCRAPE)).filter(f => f.visible && f.sel);
  const plan = { fields: {}, consents: [], unknown: [], missing: [] };
  const seen = new Set();
  const hasCompanyField = fields.some(f => classify(f) === 'company');
  for (const f of fields) {
    const k = classify(f);
    if (k === 'consent') { plan.consents.push(f.sel); continue; }
    if (!TEXTUAL(k)) { plan.unknown.push({ sel: f.sel, label: f.label || f.name, required: f.required }); continue; }
    if (seen.has(k)) continue;
    seen.add(k);
    if (k === 'password') { plan.fields[f.sel] = 'env:SIGNUP_PW'; continue; }
    // These are COMPANY accounts. If the form has no company field of its own, a bare
    // "Name" field is the account holder's name and must be the company, not a person.
    // Where the form DOES ask for company separately, First/Last stay the person -- the
    // form is explicitly asking who the contact is.
    let key = k;
    if (k === 'full_name' && !hasCompanyField) key = 'company';
    const v = id[key];
    if (v === null || v === undefined) { plan.missing.push({ key: k, label: f.label || f.name, required: f.required }); continue; }
    plan.fields[f.sel] = String(v);
  }
  return plan;
}

async function main() {
  const a = process.argv.slice(2);
  const auto = a[0] === '--auto';
  const cfgPath = auto ? null : a[0];
  if (!auto && !cfgPath) { console.error('usage: signup_assist.js <vendor.json> | --auto <url> [--dry]'); process.exit(2); }
  const dry = a.includes('--dry');
  let cfg = auto
    ? { url: a[1], port: Number(process.env.SIGNUP_PORT || 9344), submit: 'button[type=submit], input[type=submit]', waitMinutes: 10 }
    : JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  if (auto && !cfg.url) { console.error('--auto needs a URL'); process.exit(2); }
  const port = cfg.port || 9344;

  const b = await puppeteer.connect({ browserURL: `http://localhost:${port}`, defaultViewport: null });
  const p = await b.newPage();
  await p.goto(cfg.url, { waitUntil: 'networkidle2', timeout: 60000 });
  await s(6000);

  if (auto) {
    const plan = await autoPlan(p);
    console.log(JSON.stringify({ stage: 'PLAN', willFill: plan.fields, willTick: plan.consents,
                                 unknownFields: plan.unknown, missingFromIdentity: plan.missing }, null, 1));
    if (plan.missing.filter(m => m.required).length) {
      console.log(JSON.stringify({ stage: 'STOP', why: 'identity.json has no value for a REQUIRED field — I will not invent one' }));
      await b.disconnect(); process.exit(5);
    }
    cfg.fields = plan.fields; cfg.checkboxes = plan.consents; cfg.selects = {};
    if (dry) { console.log(JSON.stringify({ stage: 'DRY_RUN_END', note: 'nothing typed, nothing submitted' }));
               await b.disconnect(); process.exit(0); }
  }

  for (const [sel, val] of Object.entries(cfg.fields || {})) {
    const v = val.startsWith('env:') ? (process.env[val.slice(4)] || '') : val;
    if (!v) { console.error(`MISSING VALUE for ${sel} (${val})`); process.exit(3); }
    await humanType(p, sel, v);
  }
  for (const [sel, pattern] of Object.entries(cfg.selects || {})) {
    const v = await p.evaluate(({ sel, pattern }) => {
      const o = [...document.querySelectorAll(`${sel} option`)].map(x => x.value).filter(Boolean);
      return o.find(x => new RegExp(pattern, 'i').test(x)) || o[1] || o[0];
    }, { sel, pattern });
    if (v) await p.select(sel, v);
  }
  for (const sel of cfg.checkboxes || []) { await s(600); await p.click(sel); }

  // Most of these forms use INVISIBLE reCAPTCHA: there is NO checkbox on the page to click
  // (measured 2026-08-14 — the anchor iframe is 0x0). The token is only minted when the form
  // is SUBMITTED, and a puzzle appears only then, only sometimes. So the human step is
  // "press the real Sign Up button", NOT "tick a box that does not exist".
  const hasVisibleCheckbox = await p.evaluate(() => [...document.querySelectorAll('iframe[src*=recaptcha]')]
      .some(f => { const r = f.getBoundingClientRect(); return r.width > 10 && r.height > 10 && /anchor/.test(f.src); }));
  const startUrl = p.url();
  console.log(JSON.stringify({ stage: 'FILLED',
    doThis: hasVisibleCheckbox
      ? 'In the window: tick the "I am not a robot" box, then press Sign Up.'
      : 'In the window: press the Sign Up button. If a picture puzzle appears, solve it. There is no checkbox on this form.',
    visibleCheckbox: hasVisibleCheckbox }));

  // Wait for the HUMAN to submit. Success = we navigate away; failure = the page shows an error.
  const deadline = Date.now() + (cfg.waitMinutes || 10) * 60000;
  let outcome = null;
  while (Date.now() < deadline) {
    const st = await p.evaluate(u => ({
      moved: location.href !== u,
      url: location.href,
      err: [...document.querySelectorAll('[class*=error],[role=alert],.flash')]
             .map(e => (e.innerText || '').trim())
             .filter(t => t && !/JavaScript/i.test(t))[0] || null,
    }), startUrl).catch(() => null);
    if (st && st.moved) { outcome = { stage: 'SUBMITTED', url: st.url }; break; }
    if (st && st.err)   { outcome = { stage: 'REJECTED', message: st.err.slice(0, 200) }; break; }
    await s(2000);
  }
  if (!outcome) { console.log(JSON.stringify({ stage: 'TIMEOUT', note: 'no submit detected in the window' })); await b.disconnect(); process.exit(4); }
  console.log(JSON.stringify(outcome));
  await b.disconnect();
  process.exit(outcome.stage === 'SUBMITTED' ? 0 : 6);
}
main().catch(e => { console.error('ERR', String(e).slice(0, 200)); process.exit(1); });
