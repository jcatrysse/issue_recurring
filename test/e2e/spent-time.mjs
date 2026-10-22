// Function: estimated and spent time over a recurring issue and all its
// recurrences (docs/SPENT-TIME.md): the line in the Recurrences panel, the
// columns and report link of the module tab, the filter "Issue's Recurrence of"
// and the criterion "Recurrence of" in Spent time, the column and filter
// "Recurrence of" in the issue and time entry lists, CSV and REST.
// RMP_E2E_BEFORE=1 only takes the pictures, for the code without the feature.
import { e2e } from '../../.codex/e2e/lib.mjs';
import { rails } from './helpers.mjs';

const before = process.env.RMP_E2E_BEFORE === '1';
const ids = JSON.parse(rails(`
  User.current = admin = User.find_by!(login: 'admin')
  manager = User.find_by!(login: 'manager')
  project = Project.find_by!(identifier: 'e2e-project')
  tracker = project.trackers.first
  activity = TimeEntryActivity.default || TimeEntryActivity.first
  today = Date.current

  old = Issue.where(project_id: project.id).where("subject LIKE 'Spent series%'")
  TimeEntry.where(issue_id: old.select(:id)).delete_all
  IssueRecurrence.where(issue_id: old.select(:id)).delete_all
  old.where(parent_id: nil).order(id: :desc).each { |issue| issue.reload.destroy }

  issue = lambda do |subject, **attrs|
    Issue.create!({project: project, tracker: tracker, author: manager, subject: subject,
                   priority: IssuePriority.default || IssuePriority.first}.merge(attrs)).reload
  end
  series = lambda do |subject, mode, copies, estimated, subtask: nil|
    template = issue.call(subject, start_date: today - 90, due_date: today - 90,
                          estimated_hours: estimated)
    if subtask
      issue.call(subtask, parent_issue_id: template.id, start_date: today - 90,
                 due_date: today - 90, estimated_hours: estimated / 2)
    end
    User.current = manager
    recurrence = IssueRecurrence.new(creation_mode: :copy_first, anchor_mode: :first_issue_fixed,
                                     anchor_to_start: true, mode: mode, multiplier: 1,
                                     include_subtasks: subtask.present?)
    recurrence.issue = template.reload
    recurrence.save!
    copies.times do
      date = recurrence.advance(**{start: template.start_date, due: template.due_date})
      recurrence.create(date)
      recurrence.reload
    end
    User.current = admin
    template
  end
  log = lambda do |target, hours, days_ago, user = manager|
    TimeEntry.create!(project: project, issue: target, user: user, author: user, hours: hours,
                      spent_on: today - days_ago, activity: activity)
  end

  monthly = series.call('Spent series: monthly site check', :monthly_day_from_first, 2, 2.0,
                        subtask: 'Spent series: prepare the checklist')
  weekly = series.call('Spent series: weekly report', :weekly, 3, 0.5)
  copies = monthly.recurrence_copies.where(parent_id: nil).order(:id).to_a
  follow_up = issue.call('Spent series: follow-up found in a check', parent_issue_id: copies[0].id)

  log.call(monthly, 3.0, 85)
  log.call(monthly.children.first, 1.5, 88)
  log.call(copies[0], 2.5, 55)
  log.call(copies[0].children.first, 1.0, 57, admin)
  log.call(follow_up, 4.0, 50)
  log.call(copies[1], 2.0, 25)
  log.call(copies[1].children.first, 0.5, 26, admin)
  ([weekly] + weekly.recurrence_copies.to_a).each_with_index { |i, n| log.call(i, 1.0, 80 - 20 * n) }

  Role.find_by!(name: 'E2E full').update!(time_entries_visibility: 'all')
  Role.find_by!(name: 'E2E full').add_permission!(:view_time_entries)
  Setting.timespan_format = 'decimal'
  puts({monthly: monthly.id, weekly: weekly.id, copy: copies[0].id, copy2: copies[1].id,
        follow_up: follow_up.id}.to_json)
`).split('\n').pop());

const t = await e2e(before ? 'spent-time-before' : 'spent-time');
if (before) {
  const shot = t.shot;
  t.shot = (name, caption, options) => shot(name, `Before (without the feature): ${caption}`, options);
}
const expect = async (step, ok) => { if (!before && !ok) t.problems.push(step); };
const text = async sel => {
  const el = t.page.locator(sel).first();
  return (await el.count()) ? ((await el.textContent()) || '').trim() : '';
};
const filter = (op, values = []) =>
  `set_filter=1&f[]=issue.recurrence_of&op[issue.recurrence_of]=${encodeURIComponent(op)}` +
  values.map(v => `&v[issue.recurrence_of][]=${v}`).join('');

await t.login('manager');

// 1. Issue page: the series line, on a recurrence; its link opens the filtered list.
await t.go(`/issues/${ids.copy}`);
await expect('panel line on a recurrence',
  (await text('#issue_recurrences p.recurrence-series')) ===
    'Total (3 issues): Estimated time: 9.00 h, Spent time: 14.50 h');
await t.shot('issue-panel', 'Recurrence #' + ids.copy + ': the Recurrences panel shows the total of the whole series (template, 2 recurrences, their subtasks and a follow-up subtask added by hand)');
if (!before) {
  await t.page.click('#issue_recurrences p.recurrence-series a');
  await t.settle();
  t.check('click series link');
  await expect('linked list total', (await text('p.query-totals .total-for-hours .value')) === '14.50');
  await t.shot('filtered-list', 'The link opens Spent time with the filter "Issue\'s Recurrence of is #' + ids.monthly + '": same 14.50 h, 7 entries');
}

// 2. The template itself shows the same line.
await t.go(`/issues/${ids.monthly}`);
await expect('panel line on the template',
  (await text('#issue_recurrences p.recurrence-series')).endsWith('Spent time: 14.50 h'));

// 3. Module tab: columns, totals, report link.
await t.go('/projects/e2e-project/recurrences');
await expect('module tab spent column',
  (await text(`#project_recurrences tr:has(a[href="/issues/${ids.monthly}"]) td.spent_hours`)) === '14.50');
await expect('module tab totals',
  (await text('p.query-totals .total-for-spent-hours .value')) === '18.50');
await t.shot('module-tab', 'Module tab: Estimated time and Spent time per recurring issue, totals above the list, link "Report" top right');
if (!before) {
  await t.page.click('#content .contextual a:has-text("Report")');
  await t.settle();
  t.check('click report link');
  await expect('report rows', (await t.page.locator('#time-report tr.last-level').count()) === 2);
  await t.shot('report-by-series', 'The link opens Spent time > Report: one row per recurring issue, a column per month over the last 365 days, core\'s own period filter');
}

// 4. The filter as a user builds it: add "Issue's Recurrence of", values load on demand.
await t.go('/projects/e2e-project/time_entries');
const options = await t.page.locator('#add_filter_select option').allTextContents();
await expect('filter offered', options.includes("Issue's Recurrence of"));
if (!before) {
  await t.page.selectOption('#add_filter_select', 'issue.recurrence_of');
  await t.page.waitForSelector('#tr_issue_recurrence_of select.value option', { state: 'attached' });
  await t.page.click('#tr_issue_recurrence_of .toggle-multiselect');
  await t.settle();
  t.check('add filter');
  await t.shot('filter-values', 'Spent time: the filter "Issue\'s Recurrence of" lists the recurring issues the user can see');
}

// 5. Report with a second criterion, as a manager reads it: per series and user.
await t.go(`/projects/e2e-project/time_entries/report?${filter('*')}&criteria[]=recurrence_of&criteria[]=user&columns=month&spent_on=*`);
await t.shot('report-series-user', 'Report: rows per recurring issue, then per user, columns per month');

// 6. Issue list: filter on one series, estimated against spent per issue, totals.
await t.go(`/projects/e2e-project/issues?set_filter=1&f[]=status_id&op[status_id]=*&f[]=recurrence_of&op[recurrence_of]==&v[recurrence_of][]=${ids.monthly}` +
  '&c[]=tracker&c[]=subject&c[]=start_date&c[]=recurrence_of&c[]=estimated_hours&c[]=spent_hours&t[]=estimated_hours&t[]=spent_hours');
await expect('issue list rows', (await t.page.locator('table.issues tr.issue').count()) === 7);
await expect('issue list spent total', (await text('p.query-totals .total-for-spent-hours .value')) === '14.50');
await t.shot('issue-list-series', 'Issues filtered on one recurring issue: every issue of the series with its estimated and spent time, totals 9.00 and 14.50');

// 7. Issue list grouped by Recurrence of.
await t.go('/projects/e2e-project/issues?set_filter=1&f[]=status_id&op[status_id]=*&f[]=recurrence_of&op[recurrence_of]=*' +
  '&c[]=subject&c[]=estimated_hours&c[]=spent_hours&t[]=estimated_hours&t[]=spent_hours&group_by=recurrence_of');
await expect('issue list groups', (await t.page.locator('tr.group').count()) === 2);
await t.shot('issue-list-grouped', 'Issues grouped by "Recurrence of": a count and estimated/spent totals per series');

// 8. Time entry list grouped by Recurrence of.
await t.go('/projects/e2e-project/time_entries?set_filter=1&f[]=spent_on&op[spent_on]=*' +
  '&c[]=spent_on&c[]=user&c[]=issue&c[]=recurrence_of&c[]=hours&t[]=hours&group_by=recurrence_of');
await expect('time entry groups', (await t.page.locator('tr.group').count()) === 3);
await t.shot('time-entries-grouped', 'Spent time grouped by "Recurrence of": both series and the time outside any series, with totals');

// 9. CSV of the report and the REST API.
if (!before) {
  const csv = await (await t.page.request.get(`${t.BASE}/projects/e2e-project/time_entries/report.csv?criteria[]=recurrence_of&columns=year&spent_on=*`)).text();
  await expect('report csv', csv.split('\n').some(l => l.includes(`#${ids.monthly}`) && l.includes('14.50')));
  const auth = { Authorization: 'Basic ' + Buffer.from(`manager:${process.env.RMP_USER_PASSWORD || 'Redmine7Test!'}`).toString('base64') };
  const api = await t.page.request.get(`${t.BASE}/projects/e2e-project/time_entries.json?${filter('=', [ids.monthly])}`, { headers: auth });
  await expect('rest api', api.status() === 200 && (await api.json()).total_count === 7);
}

// 10. Role with "own time entries only": the panel counts the user's own hours.
rails("Role.find_by!(name: 'E2E full').update!(time_entries_visibility: 'own')");
await t.login('manager');
await t.go(`/issues/${ids.copy}`);
await expect('own time entries', (await text('#issue_recurrences p.recurrence-series')).endsWith('Spent time: 13.00 h'));
await t.shot('own-time-entries', 'Role limited to own time entries: the series total counts the manager\'s own 13.00 h, as the list it links to');
rails("Role.find_by!(name: 'E2E full').update!(time_entries_visibility: 'all')");

// 11. Without view_time_entries: estimated time only, no spent column or link.
rails("Role.find_by!(name: 'E2E full').remove_permission!(:view_time_entries)");
await t.go(`/issues/${ids.copy}`);
await expect('no spent time without permission',
  (await text('#issue_recurrences p.recurrence-series')) === 'Total (3 issues): Estimated time: 9.00 h');
await t.shot('no-view-time-entries', 'Without "View spent time": the panel shows estimated time only');
await t.go('/projects/e2e-project/recurrences');
await expect('module tab without spent column', (await t.page.locator('#project_recurrences td.spent_hours').count()) === 0);
await t.shot('module-tab-no-view-time-entries', 'Without "View spent time": no Spent time column and no Report link on the module tab');
rails("Role.find_by!(name: 'E2E full').add_permission!(:view_time_entries)");

// 12. Reporter (no plugin permission): no panel, no filter, no criterion.
await t.login('reporter');
await t.go(`/issues/${ids.copy}`);
await expect('reporter panel hidden', (await t.page.locator('#issue_recurrences').count()) === 0);
await t.go('/projects/e2e-project/time_entries');
await expect('reporter no filter',
  !(await t.page.locator('#add_filter_select option').allTextContents()).includes("Issue's Recurrence of"));
await t.go('/projects/e2e-project/time_entries/report?criteria[]=recurrence_of&columns=month');
await expect('reporter no criterion', (await t.page.locator('#criterias option[value="recurrence_of"]').count()) === 0);
await t.shot('reporter-no-criterion', 'Reporter (no plugin permission): Spent time > Report without the criterion "Recurrence of"');

// 13. Outsider: the private project stays closed.
await t.login('outsider');
await t.go(`/projects/e2e-private/time_entries?issue.recurrence_of=${ids.monthly}`, { status: 403 });
await t.shot('outsider-private', 'Outsider: Spent time of the private project is refused (403)');

await t.done();
