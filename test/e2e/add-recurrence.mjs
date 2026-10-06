// Function: add a recurrence to an issue (Add link in the panel, AJAX form,
// IssueRecurrencesController#new/#create, permission manage_issue_recurrences).
import { e2e } from '../../.codex/e2e/lib.mjs';
import { reset, fillRecurrence } from './helpers.mjs';

const ids = reset();
const t = await e2e('add-recurrence');
const p = () => t.page;

await t.login('manager');
await t.go(`/issues/${ids.panel}`);
await p().click('#issue_recurrences a:has-text("Add")');
await p().waitForSelector('#recurrence-form');
t.check('open form');
await t.shot('form', 'Add opens the recurrence form inside the panel (AJAX)');

// Invalid input: a date limit that is not in the future.
await fillRecurrence(p(), { multiplier: 1, mode: 'weekly', limit_mode: 'date_limit' });
await p().evaluate(() => {
  const d = new Date(); d.setDate(d.getDate() - 1);
  const el = document.getElementById('recurrence_date_limit');
  el.removeAttribute('min'); el.value = d.toISOString().split('T')[0];
});
await p().click('#recurrence-form input[type=submit]');
await p().waitForSelector('#recurrence-errors #errorExplanation', { timeout: 10000 })
  .catch(() => t.problems.push('invalid date limit: no error shown'));
t.check('submit invalid');
if (await p().locator('#recurrences tr').count()) t.problems.push('invalid input still created a recurrence');
if (await p().locator('#flash_notice').count()) t.problems.push('notice shown next to an error');
await t.shot('invalid-date-limit', 'A date limit in the past is refused with a message, nothing is created, no success notice');

// Valid: every 1 week, no limit.
await fillRecurrence(p(), { limit_mode: 'no_limit' });
await p().click('#recurrence-form input[type=submit]');
await p().waitForSelector('#recurrences tr', { timeout: 10000 }).catch(() => t.problems.push('recurrence not listed'));
t.check('submit valid');
const row = p().locator('#recurrences tr').first();
const text = await row.innerText();
if (!/every\s+1\s+week/i.test(text)) t.problems.push(`unexpected description: ${text}`);
if (!(await p().locator('#flash_notice', { hasText: 'New issue recurrence created.' }).count())) t.problems.push('no success notice');
if ((await row.locator('a.icon-edit svg, a.icon-del svg').count()) !== 2) t.problems.push('edit/delete icons missing');
if (await p().locator('#recurrence-form').count()) t.problems.push('form still open after create');
await t.shot('created', 'Created: notice, description "every 1 week", next/predicted dates, edit and delete icons');

await t.go(`/issues/${ids.panel}`);
if ((await p().locator('#recurrences tr').count()) !== 1) t.problems.push('recurrence not shown after reload');
await t.shot('after-reload', 'After a reload the recurrence is still there (saved)');

// Without manage_issue_recurrences: no Add link, and the request itself is refused.
await t.login('reporter');
await t.go(`/issues/${ids.panel}`);
const token = await p().locator('meta[name=csrf-token]').getAttribute('content');
const res = await p().request.post(`${t.BASE}/issues/${ids.panel}/recurrences.js`, {
  headers: { 'X-CSRF-Token': token, 'X-Requested-With': 'XMLHttpRequest' },
  form: { 'recurrence[mode]': 'weekly', 'recurrence[multiplier]': '1' },
});
if (res.status() !== 403) t.problems.push(`reporter create: HTTP ${res.status()}, expected 403`);
const res2 = await p().request.get(`${t.BASE}/issues/${ids.panel}/recurrences/new.js`, {
  headers: { 'X-Requested-With': 'XMLHttpRequest' } });
if (res2.status() !== 403) t.problems.push(`reporter new: HTTP ${res2.status()}, expected 403`);
await t.go(`/issues/${ids.panel}/recurrences/new`, { status: 403 });
await t.shot('reporter-refused', `Reporter: new form refused (403); POST create.js answered ${res.status()}, new.js ${res2.status()}`);

await t.login('outsider');
await t.go(`/issues/${ids.private}/recurrences/new`, { status: 403 });
await t.shot('outsider-refused', 'Outsider: the form for an issue of the private project is refused (403)');

await t.done();
