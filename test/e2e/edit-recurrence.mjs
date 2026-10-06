// Function: edit a recurrence (Edit icon in the panel, #edit/#update).
import { e2e } from '../../.codex/e2e/lib.mjs';
import { reset, rails, fillRecurrence } from './helpers.mjs';

const ids = reset();
const rid = rails(`User.current = User.find_by(login: 'admin'); r = IssueRecurrence.create!(issue: Issue.find(${ids.panel}), mode: :weekly, multiplier: 1, anchor_mode: :first_issue_fixed); print r.id`).split('\n').pop();
const t = await e2e('edit-recurrence');
const p = () => t.page;

await t.login('manager');
await t.go(`/issues/${ids.panel}`);
await p().click(`#recurrence-${rid} a.icon-edit`);
await p().waitForSelector('#recurrence-form');
t.check('open edit form');
if ((await p().locator('#recurrence_mode').inputValue()) !== 'weekly') t.problems.push('edit form does not show the saved mode');
await t.shot('form', 'Edit opens the form with the saved values (every 1 week)');

// Invalid: count limit 0 (the browser's min=1 is removed to reach the server).
await fillRecurrence(p(), { limit_mode: 'count_limit' });
await p().evaluate(() => { const e = document.getElementById('recurrence_count_limit'); e.removeAttribute('min'); e.value = 'x'; });
await fillRecurrence(p(), { multiplier: 0 });
await p().evaluate(() => document.getElementById('recurrence_multiplier').removeAttribute('min'));
await p().click('#recurrence-form input[type=submit]');
await p().waitForSelector('#recurrence-errors #errorExplanation', { timeout: 10000 })
  .catch(() => t.problems.push('invalid edit: no error shown'));
t.check('submit invalid');
await t.shot('invalid', 'Multiplier 0 is refused with a message; the saved recurrence is unchanged');
const still = rails(`print IssueRecurrence.find(${rid}).multiplier`).split('\n').pop();
if (still !== '1') t.problems.push(`invalid edit changed multiplier to ${still}`);

await fillRecurrence(p(), { multiplier: 2, limit_mode: 'count_limit', count_limit: 3 });
await p().click('#recurrence-form input[type=submit]');
await p().waitForSelector('#flash_notice', { timeout: 10000 }).catch(() => t.problems.push('no notice after update'));
t.check('submit valid');
const text = await p().locator(`#recurrence-${rid}`).innerText();
if (!/every\s+2\s+weeks/i.test(text) || !/3 recurrences/i.test(text)) t.problems.push(`description not updated: ${text}`);
if (!(await p().locator('#flash_notice', { hasText: 'Issue recurrence updated.' }).count())) t.problems.push('wrong notice');
await t.shot('updated', 'Updated: notice, "every 2 weeks ... until 3 recurrences"');

await t.login('reporter');
await t.go(`/recurrences/${rid}/edit`, { status: 403 });
await t.shot('reporter-refused', 'Reporter: the edit form is refused (403)');
await t.go(`/issues/${ids.panel}`);
const token = await p().locator('meta[name=csrf-token]').getAttribute('content');
const res = await p().request.patch(`${t.BASE}/recurrences/${rid}.js`, {
  headers: { 'X-CSRF-Token': token, 'X-Requested-With': 'XMLHttpRequest' },
  form: { 'recurrence[multiplier]': '9' } });
if (res.status() !== 403) t.problems.push(`reporter update: HTTP ${res.status()}, expected 403`);
const after = rails(`print IssueRecurrence.find(${rid}).multiplier`).split('\n').pop();
if (after !== '2') t.problems.push(`reporter changed multiplier to ${after}`);

await t.login('manager');
await t.go('/recurrences/999999/edit', { status: 404 });
await t.shot('not-found', 'A recurrence that does not exist: 404');

await t.done();
