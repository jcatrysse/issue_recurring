// Function: the "Recurrences" panel on the issue page (hook
// view_issues_show_description_bottom, permission view_issue_recurrences).
import { e2e } from '../../.codex/e2e/lib.mjs';
import { reset, rails } from './helpers.mjs';

const ids = reset();
const t = await e2e('issue-panel');

await t.login('manager');
await t.go(`/issues/${ids.panel}`);
if (!(await t.page.locator('#issue_recurrences').count())) t.problems.push('manager: no recurrences panel');
if (!(await t.page.locator('#issue_recurrences a', { hasText: 'Add' }).count())) t.problems.push('manager: no Add link');
if (await t.page.locator('#recurrences tr').count()) t.problems.push('manager: recurrences listed on a fresh issue');
await t.shot('manager-empty', 'Manager (view + manage): panel with Add link, no recurrence yet (empty state)');

await t.login('admin');
await t.go(`/issues/${ids.panel}`);
if (!(await t.page.locator('#issue_recurrences a', { hasText: 'Add' }).count())) t.problems.push('admin: no Add link');
await t.shot('admin', 'Admin: panel with Add link');

await t.login('reporter');
await t.go(`/issues/${ids.panel}`);
if (await t.page.locator('#issue_recurrences').count()) t.problems.push('reporter: panel shown without view_issue_recurrences');
await t.shot('reporter-hidden', 'Reporter (no plugin permission): the issue shows, the panel does not');

await t.login('outsider');
await t.go(`/issues/${ids.private}`, { status: 403 });
await t.shot('outsider-private', 'Outsider: an issue of the private project is refused (403)');

// Module switched off in the project: no panel, even for the manager.
rails("Project.find_by(identifier: 'e2e-private').disable_module!(:issue_recurring)");
await t.login('manager');
await t.go(`/issues/${ids.private}`);
if (await t.page.locator('#issue_recurrences').count()) t.problems.push('module off: panel still shown');
await t.shot('module-off', 'Module "Issue recurring" disabled in the project: no panel for the manager');
rails("Project.find_by(identifier: 'e2e-private').enable_module!(:issue_recurring)");
await t.go(`/issues/${ids.private}`);
if (!(await t.page.locator('#issue_recurrences').count())) t.problems.push('module on: panel missing');
await t.shot('module-on', 'Module enabled again: the panel is back');

await t.done();
