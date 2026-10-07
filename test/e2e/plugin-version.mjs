// Decision issue_recurring-q3 (Jan, 2026-10-07): the Redmine 7 version is
// 1.8.0-geoxyz, shown on Administration > Plugins. Only admins see that page.
import { e2e } from '../../.codex/e2e/lib.mjs';

const t = await e2e('plugin-version');
const p = () => t.page;

await t.login('admin');
await t.go('/admin/plugins');
const row = p().locator('tr#plugin-issue_recurring');
const text = await row.innerText().catch(() => '');
if (!/1\.8\.0-geoxyz/.test(text)) t.problems.push(`plugin row: ${text}`);
await t.shot('admin', `Admin: Administration > Plugins lists "Issue recurring plugin" with version 1.8.0-geoxyz`);

for (const user of ['manager', 'reporter', 'outsider']) {
  await t.login(user);
  await t.go('/admin/plugins', { status: 403 });
  await t.shot(`${user}-refused`, `${user}: the plugin list is refused (403)`);
}
await t.done();
