// Function: Administration > Plugins > Issue recurring > Configure
// (author, keep assignee, journal mode, copy recurrences, copy relation types,
// renew ahead), saved through SettingsControllerPatch.
import { e2e } from '../../.codex/e2e/lib.mjs';
import { reset, rails } from './helpers.mjs';

reset();
const t = await e2e('plugin-settings');
const p = () => t.page;

await t.login('admin');
await t.go('/settings/plugin/issue_recurring');
await t.sudo();
await t.shot('defaults', 'Admin: the settings with their defaults');

const managerId = rails("print User.find_by(login: 'manager').id").split('\n').pop();
await p().selectOption('#settings_author_id', managerId);
await p().check('#settings_keep_assignee');
await p().selectOption('#settings_journal_mode', 'on_reopen');
await p().check('#settings_copy_recurrences');
await p().check('#settings_copy_relation_types_relates');
await p().check('#settings_copy_relation_types_blocks');
await p().fill('#settings_ahead_multiplier', '-2');
await p().selectOption('#settings_ahead_mode', 'weeks');
await p().click('form input[name=commit]');
if (!(await p().locator('#settings_ahead_multiplier:invalid').count())) t.problems.push('negative value not refused by the form');
await t.shot('negative-refused', 'A negative "renew ahead" is refused by the form before it is sent');
await p().fill('#settings_ahead_multiplier', '2');
await p().click('form input[name=commit]');
await t.sudo();
await t.settle();
t.check('save');
if (!(await p().locator('#flash_notice').count())) t.problems.push('no "Successful update"');
const stored = rails('print Setting.plugin_issue_recurring.to_json').split('\n').pop();
const s = JSON.parse(stored);
const want = { author_login: 'manager', keep_assignee: true, journal_mode: 'on_reopen', copy_recurrences: true,
               ahead_multiplier: 2, ahead_mode: 'weeks' };
for (const [k, v] of Object.entries(want)) if (s[k] !== v) t.problems.push(`${k}: stored ${JSON.stringify(s[k])}, expected ${JSON.stringify(v)}`);
if (JSON.stringify([...s.copy_relation_types].sort()) !== JSON.stringify(['blocks', 'relates'])) t.problems.push(`copy_relation_types: ${JSON.stringify(s.copy_relation_types)}`);
if ((await p().locator('#settings_ahead_multiplier').inputValue()) !== '2') t.problems.push('ahead not shown as 2');
await t.shot('saved', `Saved: "Successful update", the values are shown again. Stored: ${stored}`);

// Values sent by hand: unknown ones fall back to the defaults, -3 is stored as 3.
const token = await p().locator('meta[name=csrf-token]').getAttribute('content');
const res = await p().request.post(`${t.BASE}/settings/plugin/issue_recurring`, {
  headers: { 'X-CSRF-Token': token },
  form: { 'settings[author_id]': '0', 'settings[journal_mode]': 'bogus', 'settings[ahead_mode]': 'decades',
          'settings[ahead_multiplier]': '-3', 'settings[copy_relation_types][]': 'bogus' },
  maxRedirects: 0 });
const s2 = JSON.parse(rails('print Setting.plugin_issue_recurring.to_json').split('\n').pop());
if (s2.journal_mode !== 'never' || s2.ahead_mode !== 'days' || s2.ahead_multiplier !== 3 ||
    s2.copy_relation_types.length !== 0 || s2.author_login !== null) t.problems.push(`invalid values stored: ${JSON.stringify(s2)}`);
await t.go('/settings/plugin/issue_recurring');
await t.shot('invalid-values', `Hand-made POST with unknown values and -3 (HTTP ${res.status()}): stored ${JSON.stringify(s2)}`);

await t.login('manager');
await t.go('/settings/plugin/issue_recurring', { status: 403 });
await t.shot('manager-refused', 'Manager (not admin): the plugin settings are refused (403)');

reset();
await t.done();
