/**
 * detect_fields.js — map an arbitrary signup form to our standard identity.
 * CREATED BY CLAUDE 2026-08-14 (ET). No secrets. Pure read + classify.
 * Matches on label text, name, id, placeholder, autocomplete — in that order of trust.
 */
const RULES = [
  ['password',   /pass(word)?/i,                                   /new-password|current-password/i],
  ['email',      /e-?mail/i,                                       /email/i],
  ['phone',      /phone|mobile|tel(ephone)?/i,                     /tel/i],
  ['company',    /company|organi[sz]ation|business|firm|tax.?name|account.?name/i, /organization/i],
  ['first_name', /first.?name|given.?name|forename/i,              /given-name/i],
  ['last_name',  /last.?name|surname|family.?name/i,               /family-name/i],
  ['full_name',  /^(your.?)?(full.?)?name$|contact.?name/i,        /^name$/i],
  ['job_title',  /job.?title|role|position/i,                      /organization-title/i],
  ['website',    /web.?site|url|domain/i,                          /url/i],
  ['address1',   /address(.?line.?1)?|street/i,                    /address-line1|street-address/i],
  ['city',       /city|town/i,                                     /address-level2/i],
  ['state',      /state|province|region/i,                         /address-level1/i],
  ['postcode',   /zip|postal|post.?code/i,                         /postal-code/i],
  ['country',    /country/i,                                       /country/i],
];

function classify(f) {
  const hay = [f.label, f.name, f.id, f.placeholder, f.ariaLabel].filter(Boolean).join(' ');
  // Checkboxes/radios are NEVER text targets. Typing into one is a real defect —
  // an "accept the terms and privacy statements" label used to match the /state/ rule.
  if (f.type === 'checkbox' || f.type === 'radio') {
    return /terms|privacy|agree|accept|consent|policy/i.test(hay) ? 'consent' : 'choice';
  }
  if (f.type === 'password') return 'password';
  if (f.type === 'email') return 'email';
  if (f.type === 'tel') return 'phone';
  for (const [key, re, acRe] of RULES) {
    if (f.autocomplete && acRe && acRe.test(f.autocomplete)) return key;
    if (re.test(hay)) return key;
  }
  return null;
}

const SCRAPE = () => [...document.querySelectorAll('input,select,textarea')]
  .filter(e => !['hidden','submit','button','image'].includes(e.type))
  .map(e => {
    const r = e.getBoundingClientRect();
    let label = (document.querySelector(`label[for="${e.id}"]`) || {}).innerText || '';
    if (!label) { const p = e.closest('label'); if (p) label = p.innerText || ''; }
    return { tag: e.tagName.toLowerCase(), type: e.type, name: e.name, id: e.id,
             placeholder: e.placeholder, ariaLabel: e.getAttribute('aria-label') || '',
             autocomplete: e.getAttribute('autocomplete') || '', required: e.required,
             label: (label || '').trim().slice(0, 60),
             visible: !(r.width === 0 || r.height === 0 || getComputedStyle(e).display === 'none'),
             sel: e.id ? `#${CSS.escape(e.id)}` : (e.name ? `[name="${CSS.escape(e.name)}"]` : null) };
  });

const TEXTUAL = k => k && !['consent','choice'].includes(k);
module.exports = { classify, SCRAPE, TEXTUAL };
