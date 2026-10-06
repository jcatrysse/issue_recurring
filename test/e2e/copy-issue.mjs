// Function: setting "Copy recurrences on issue copy" (IssuePatch#copy_from):
// copying an issue through core's Copy copies its recurrences only when the
// setting is on; the copy never keeps "recurrence of".
import { e2e } from '../../.codex/e2e/lib.mjs';
import { reset, rails } from './helpers.mjs';

const ids = reset();
rails(`User.current = User.find_by(login: 'admin')
  IssueRecurrence.create!(issue: Issue.find(${ids.panel}), mode: :weekly, multiplier: 2, anchor_mode: :first_issue_fixed)`);
const t = await e2e('copy-issue');
const p = () => t.page;
const last = out => out.split('\n').filter(Boolean).pop();

async function copyIssue(label) {
  await t.go(`/projects/e2e-project/issues/${ids.panel}/copy`);
  await p().fill('#issue_subject', `Copy of the panel issue (${label})`);
  await p().click('#issue-form input[name=commit]');
  await t.settle();
  t.check(`copy ${label}`);
  const m = p().url().match(/\/issues\/(\d+)$/);
  if (!m) t.problems.push(`copy ${label}: still on ${p().url()}`);
  return m && m[1];
}

await t.login('manager');
// Setting off (default): the copy has no recurrence.
const off = await copyIssue('setting off');
const offCount = last(rails(`print IssueRecurrence.where(issue_id: ${off}).count`));
if (offCount !== '0') t.problems.push(`setting off: copy has ${offCount} recurrence(s)`);
if (await p().locator('#recurrences tr').count()) t.problems.push('setting off: recurrence shown on the copy');
await t.shot('setting-off', 'Setting off (default): the copied issue has no recurrence');

rails("Setting.plugin_issue_recurring = Setting.plugin_issue_recurring.merge(copy_recurrences: true)");
const on = await copyIssue('setting on');
const onInfo = JSON.parse(last(rails(`r = IssueRecurrence.where(issue_id: ${on}); i = Issue.find(${on})
  print({count: r.count, mode: r.first&.mode, multiplier: r.first&.multiplier, recurrence_of: i.recurrence_of_id}.to_json)`)));
if (onInfo.count !== 1 || onInfo.mode !== 'weekly' || onInfo.multiplier !== 2) t.problems.push(`setting on: ${JSON.stringify(onInfo)}`);
if (onInfo.recurrence_of !== null) t.problems.push('copy keeps recurrence_of');
if (!(await p().locator('#recurrences tr', { hasText: 'every 2 weeks' }).count())) t.problems.push('setting on: recurrence not shown');
await t.shot('setting-on', 'Setting on: the copied issue gets its own copy of the recurrence (every 2 weeks), no "recurrence of"');

// A recurrence copy copied by hand does not stay a "recurrence of" the original.
const copyOfCopy = last(rails(`User.current = User.find_by(login: 'admin'); src = Issue.find(${on})
  src.update_column(:recurrence_of_id, ${ids.panel}); c = Issue.new.copy_from(src); c.subject = 'Copy of a recurrence'; c.save!; print c.id`));
const coc = last(rails(`print Issue.find(${copyOfCopy}).recurrence_of_id.inspect`));
if (coc !== 'nil') t.problems.push(`copy of a recurrence keeps recurrence_of ${coc}`);
await t.go(`/issues/${copyOfCopy}`);
if (await p().locator('#issue_recurrences', { hasText: 'This is a recurrence of' }).count()) t.problems.push('copy of a recurrence says "recurrence of"');
await t.shot('copy-of-recurrence', 'Copying an issue that is itself a recurrence: the copy is not marked "recurrence of"');

reset();
await t.done();
