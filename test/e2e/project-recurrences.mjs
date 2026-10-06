// Function: the project tab "Issue recurrences" (menu item, #index, delete
// from the list), permission view_issue_recurrences.
import { e2e } from '../../.codex/e2e/lib.mjs';
import { reset, rails } from './helpers.mjs';

const ids = reset();
const rid = rails(`User.current = User.find_by(login: 'admin'); r = IssueRecurrence.create!(issue: Issue.find(${ids.panel}), mode: :daily, multiplier: 3, anchor_mode: :first_issue_fixed, count_limit: 5); print r.id`).split('\n').pop();
const t = await e2e('project-recurrences');
const p = () => t.page;

await t.login('manager');
await t.go('/projects/e2e-project');
const tab = p().locator('#main-menu a.issue-recurrences');
if (!(await tab.count())) t.problems.push('manager: no project menu tab');
await tab.click();
await t.settle();
t.check('open tab');
const row = p().locator(`#project_recurrences tr#recurrence-${rid}`);
if (!(await row.count())) t.problems.push('recurrence not listed');
const text = await row.innerText().catch(() => '');
if (!/Recurring panel issue/.test(text) || !/day/.test(text)) t.problems.push(`unexpected row: ${text}`);
if (!(await row.locator('a.icon-del svg').count())) t.problems.push('no delete icon');
await t.shot('list', 'Manager: tab "Issue recurrences" lists issue, mode, last/next/predicted, limit, count and a delete icon');

await t.go('/projects/e2e-private/recurrences');
if (!(await p().locator('.nodata').count())) t.problems.push('empty project: no "No data" message');
await t.shot('empty', 'Empty state: a project without recurrences shows "No data to display"');

await t.go('/projects/e2e-project/recurrences');
await row.locator('a.icon-del').click();
await t.settle();
t.check('delete from list');
await p().waitForFunction(id => !document.getElementById(`recurrence-${id}`), rid, { timeout: 10000 })
  .catch(() => t.problems.push('row not removed after delete'));
if (rails(`print IssueRecurrence.exists?(${rid})`).split('\n').pop() !== 'false') t.problems.push('not deleted');
await t.shot('deleted', 'Delete from the list removes the row (and the record)');

await t.login('reporter');
await t.go('/projects/e2e-project');
if (await p().locator('#main-menu a.issue-recurrences').count()) t.problems.push('reporter: menu tab shown');
await t.go('/projects/e2e-project/recurrences', { status: 403 });
await t.shot('reporter-refused', 'Reporter: no tab in the project menu, the list is refused (403)');

await t.login('outsider');
await t.go('/projects/e2e-private/recurrences', { status: 403 });
await t.shot('outsider-private', 'Outsider: the list of the private project is refused (403)');

await t.anonymous();
await t.go('/projects/e2e-project/recurrences');
if (!/\/login/.test(p().url())) t.problems.push(`anonymous not sent to login: ${p().url()}`);
await t.shot('anonymous', 'Anonymous: sent to the login page');

await t.login('manager');
await t.go('/projects/no-such-project/recurrences', { status: 404 });

await t.done();
