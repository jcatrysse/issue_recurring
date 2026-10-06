// Function: renewal by the cron task rake redmine:issue_recurring:renew_all
// (IssueRecurrence.renew_all): copies, reopen, "recurrence of" link, mails,
// Redmine 7 webhooks, the copy-relations and journal settings.
import http from 'node:http';
import os from 'node:os';
import { e2e } from '../../.codex/e2e/lib.mjs';
import { reset, rails, renewAll } from './helpers.mjs';

const ids = reset();
const t = await e2e('renew');
const p = () => t.page;
const last = out => out.split('\n').filter(Boolean).pop();

// Webhook receiver on a non-loopback address (Redmine refuses loopback targets).
const ip = Object.values(os.networkInterfaces()).flat().find(a => a.family === 'IPv4' && !a.internal).address;
const hooks = [];
const server = http.createServer((req, res) => {
  let body = '';
  req.on('data', c => { body += c; });
  req.on('end', () => { try { hooks.push(JSON.parse(body)); } catch { /* not json */ } res.end('ok'); });
}).listen(4568, '0.0.0.0');

rails(`Setting.webhooks_enabled = '1'; Webhook.where("url LIKE '%:4568/%'").destroy_all
  w = Webhook.new(url: 'http://${ip}:4568/hook', user: User.find_by(login: 'admin'), active: true,
                  events: %w(issue.created issue.updated))
  w.projects = [Project.find_by(identifier: 'e2e-project')]; w.save!
  User.find_by(login: 'reporter').update!(mail_notification: 'all')
  Setting.plugin_issue_recurring = Setting.plugin_issue_recurring.merge(copy_relation_types: ['relates'], journal_mode: :on_reopen)
  User.current = User.find_by(login: 'admin')
  IssueRecurrence.create!(issue: Issue.find(${ids.copy}), mode: :daily, multiplier: 1, anchor_mode: :first_issue_fixed)
  IssueRecurrence.create!(issue: Issue.find(${ids.reopen}), creation_mode: :reopen, mode: :weekly, multiplier: 1,
                          anchor_mode: :last_issue_flexible)`);

await t.login('manager');
await t.go(`/issues/${ids.copy}`);
await t.shot('before', 'Before the cron run: daily copy recurrence, "Last: -", next dates up to tomorrow');
await t.go(`/issues/${ids.reopen}`);
await t.shot('reopen-before', 'Before the cron run: the reopen-mode issue is closed and relates to "Recurring related issue"');

const since = Date.now();
const copyMails = () => {
  const f = t.mails(0).find(m => m.to === 'reporter@example.net');
  return f ? (f.body.match(/^Subject: .*Recurring copy issue/gm) || []).length : 0;
};
const mailsBefore = copyMails();
const out = renewAll();
await new Promise(r => setTimeout(r, 1500));
console.log(out.trim().split('\n').slice(0, 12).join('\n'));

const info = JSON.parse(last(rails(`r = IssueRecurrence.find_by(issue_id: ${ids.copy}); c = Issue.where(recurrence_of_id: ${ids.copy}).order(:id)
  ro = Issue.find(${ids.reopen})
  print({count: r.count, last: r.last_issue_id, copies: c.map { |i| [i.id, i.start_date.to_s, i.due_date.to_s, i.status.name] },
         copy_relates: c.map { |i| IssueRelation.where(relation_type: 'relates').where('issue_from_id = :i OR issue_to_id = :i', i: i.id).count },
         reopen_closed: ro.closed?, reopen_dates: [ro.start_date.to_s, ro.due_date.to_s],
         reopen_relations: IssueRelation.where('issue_from_id = :i OR issue_to_id = :i', i: ro.id).count}.to_json)`)));
console.log(JSON.stringify(info));
if (info.copies.length < 1) t.problems.push('rake created no copy');
if (info.count !== info.copies.length || info.last !== info.copies.at(-1)?.[0]) t.problems.push(`count/last wrong: ${JSON.stringify(info)}`);
if (info.copies.some(c => c[3] !== 'New')) t.problems.push('a copy is not New');
if (info.copy_relates.some(n => n !== 1)) t.problems.push(`relates not copied to every copy: ${info.copy_relates}`);
if (info.reopen_closed) t.problems.push('reopen issue still closed');
if (info.reopen_relations !== 1) t.problems.push(`reopened issue lost its relation (${info.reopen_relations})`);

await t.go(`/issues/${ids.copy}`);
if (!(await p().locator('#recurrences', { hasText: `#${info.last}` }).count())) t.problems.push('panel does not link the last copy');
await t.shot('after', `After rake renew_all: ${info.copies.length} copies ${JSON.stringify(info.copies)}; "Last: #${info.last}" links the newest`);

await t.go(`/issues/${info.last}`);
if (!(await p().locator('#issue_recurrences', { hasText: 'Recurring copy issue' }).count())) t.problems.push('copy does not show "recurrence of"');
if (!(await p().locator('#relations', { hasText: 'Recurring related issue' }).count())) t.problems.push('copy has no copied relation');
await t.shot('copy', 'A copy: status New, its own dates, "This is a recurrence of #...", the "relates" relation copied (setting)');

await t.go(`/issues/${ids.reopen}`);
if (!(await p().locator('#relations', { hasText: 'Recurring related issue' }).count())) t.problems.push('reopened issue: relation gone');
await t.shot('reopened', `Reopen mode: the issue is open again with dates ${info.reopen_dates.join(' - ')}, its relation kept, a journal entry (journal mode "on reopen")`);

const mails = t.mails(since);
// delivery_method :file appends every message to one file per recipient
const toReporter = { length: copyMails() - mailsBefore };
if (toReporter.length !== info.copies.length) t.problems.push(`mails about the copies to reporter: ${toReporter.length}, copies ${info.copies.length}`);

const createdHooks = hooks.filter(h => h.type === 'issue.created').map(h => h.data.issue.id);
const want = info.copies.map(c => c[0]);
if (want.some(id => !createdHooks.includes(id))) t.problems.push(`webhooks: created ${JSON.stringify(createdHooks)}, copies ${JSON.stringify(want)}`);
const reopenHook = hooks.find(h => h.type === 'issue.updated' && h.data.issue.id === ids.reopen);
if (!reopenHook) t.problems.push('no issue.updated webhook for the reopened issue');
console.log(`mail files ${mails.length}, messages to reporter about the copy issue ${toReporter.length}; hooks ${JSON.stringify(hooks.map(h => [h.type, h.data.issue.id]))}`);
await t.go(`/issues/${info.last}`);
await t.shot('evidence', `Mails: ${toReporter.length} "Recurring copy issue" messages to reporter (mail_notification all); webhooks received: issue.created for ${JSON.stringify(createdHooks)}, issue.updated for the reopened #${ids.reopen}: ${!!reopenHook}`);

// Run again: nothing more is due, nothing is created.
const again = renewAll();
const againN = (again.match(/creating recurrence/g) || []).length;
if (againN !== 0) t.problems.push(`second run created ${againN}`);
console.log(`second run: ${againN} created`);

rails(`Webhook.where("url LIKE '%:4568/%'").destroy_all; Setting.webhooks_enabled = '0'
  User.find_by(login: 'reporter').update!(mail_notification: 'only_my_events')`);
server.close();
reset();
await t.done();
