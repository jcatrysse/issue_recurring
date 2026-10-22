# spent-time-before

Run 2026-10-22T16:35:00.922Z against http://127.0.0.1:3000.

| screenshot | user | URL | shows |
|---|---|---|---|
| ![](spent-time-before-issue-panel.png) | manager | `/issues/37` | Before (without the feature): Recurrence #37: the Recurrences panel shows the total of the whole series (template, 2 recurrences, their subtasks and a follow-up subtask added by hand) |
| ![](spent-time-before-module-tab.png) | manager | `/projects/e2e-project/recurrences` | Before (without the feature): Module tab: Estimated time and Spent time per recurring issue, totals above the list, link "Report" top right |
| ![](spent-time-before-report-series-user.png) | manager | `/projects/e2e-project/time_entries/report?set_filter=1&f[]=issue.recurrence_of&op[issue.recurrence_of]=*&criteria[]=recurrence_of&criteria[]=user&columns=month&spent_on=*` | Before (without the feature): Report: rows per recurring issue, then per user, columns per month |
| ![](spent-time-before-issue-list-series.png) | manager | `/projects/e2e-project/issues?set_filter=1&f[]=status_id&op[status_id]=*&f[]=recurrence_of&op[recurrence_of]==&v[recurrence_of][]=35&c[]=tracker&c[]=subject&c[]=start_date&c[]=recurrence_of&c[]=estimated_hours&c[]=spent_hours&t[]=estimated_hours&t[]=spent_hours` | Before (without the feature): Issues filtered on one recurring issue: every issue of the series with its estimated and spent time, totals 9.00 and 14.50 |
| ![](spent-time-before-issue-list-grouped.png) | manager | `/projects/e2e-project/issues?set_filter=1&f[]=status_id&op[status_id]=*&f[]=recurrence_of&op[recurrence_of]=*&c[]=subject&c[]=estimated_hours&c[]=spent_hours&t[]=estimated_hours&t[]=spent_hours&group_by=recurrence_of` | Before (without the feature): Issues grouped by "Recurrence of": a count and estimated/spent totals per series |
| ![](spent-time-before-time-entries-grouped.png) | manager | `/projects/e2e-project/time_entries?set_filter=1&f[]=spent_on&op[spent_on]=*&c[]=spent_on&c[]=user&c[]=issue&c[]=recurrence_of&c[]=hours&t[]=hours&group_by=recurrence_of` | Before (without the feature): Spent time grouped by "Recurrence of": both series and the time outside any series, with totals |
| ![](spent-time-before-own-time-entries.png) | manager | `/issues/37` | Before (without the feature): Role limited to own time entries: the series total counts the manager's own 13.00 h, as the list it links to |
| ![](spent-time-before-no-view-time-entries.png) | manager | `/issues/37` | Before (without the feature): Without "View spent time": the panel shows estimated time only |
| ![](spent-time-before-module-tab-no-view-time-entries.png) | manager | `/projects/e2e-project/recurrences` | Before (without the feature): Without "View spent time": no Spent time column and no Report link on the module tab |
| ![](spent-time-before-reporter-no-criterion.png) | reporter | `/projects/e2e-project/time_entries/report?criteria[]=recurrence_of&columns=month` | Before (without the feature): Reporter (no plugin permission): Spent time > Report without the criterion "Recurrence of" |
| ![](spent-time-before-outsider-private.png) | outsider | `/projects/e2e-private/time_entries?issue.recurrence_of=35` | Before (without the feature): Outsider: Spent time of the private project is refused (403) |
