// Function: delete a recurrence (Delete icon in the panel, #destroy).
import { e2e } from '../../.codex/e2e/lib.mjs';
import { reset, rails } from './helpers.mjs';

const ids = reset();
const make = () => rails(`User.current = User.find_by(login: 'admin'); r = IssueRecurrence.create!(issue: Issue.find(${ids.panel}), mode: :weekly, multiplier: 1, anchor_mode: :first_issue_fixed); print r.id`).split('\n').pop();
const rid = make();
const t = await e2e('delete-recurrence');
const p = () => t.page;

// Without the permission first: the request is refused and nothing is deleted.
await t.login('reporter');
await t.go(`/issues/${ids.panel}`);
const token = await p().locator('meta[name=csrf-token]').getAttribute('content');
const res = await p().request.delete(`${t.BASE}/recurrences/${rid}.js`, {
  headers: { 'X-CSRF-Token': token, 'X-Requested-With': 'XMLHttpRequest' } });
if (res.status() !== 403) t.problems.push(`reporter delete: HTTP ${res.status()}, expected 403`);
if (rails(`print IssueRecurrence.exists?(${rid})`).split('\n').pop() !== 'true') t.problems.push('reporter deleted the recurrence');

await t.login('manager');
await t.go(`/issues/${ids.panel}`);
await t.shot('before', `Manager: the recurrence before deleting (reporter DELETE answered ${res.status()}, record kept)`);
await p().click(`#recurrence-${rid} a.icon-del`);
await p().waitForSelector('#flash_notice', { timeout: 10000 }).catch(() => t.problems.push('no notice after delete'));
t.check('delete');
if (await p().locator(`#recurrence-${rid}`).count()) t.problems.push('row still shown');
if (!(await p().locator('#flash_notice', { hasText: 'Issue recurrence deleted.' }).count())) t.problems.push('wrong notice');
await t.shot('deleted', 'Deleted: row removed, notice "Issue recurrence deleted."');
if (rails(`print IssueRecurrence.exists?(${rid})`).split('\n').pop() !== 'false') t.problems.push('record still in the database');

await t.done();
