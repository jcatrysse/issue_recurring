# Independent review: spent time over recurring issues (2026-10-22)

Reviewer: an independent Claude agent, read-only, given the code and the core sources (5.1-stable,
7.0-stable-GEOxyz), not the implementer's conclusions. Scope: `e6fae03..c43bfae` on
`spent-time-master` without the two test-infrastructure commits; the same code is on
`redmine70-migration` (`d1aa81c..0b36c13`). Fixes: `4e1817f` on `spent-time-master`, `e46c157` here.

1. **Major. Time on issues the user cannot see counted differently per operator.** Spent time joins
   `issues` only for visible issues (`TimeEntry.left_join_issue`), so `*`, `!*`, the report and
   grouping put such time outside the series, while `=`, `!` (on `time_entries.issue_id`) and the
   totals counted it.
   Resolution: fixed in `4e1817f`: the filter works on the joined `issues.id`, totals count visible
   issues only, the column returns nothing for an invisible issue of a time entry. Test
   `test_time_on_issues_the_user_cannot_see` (red on the code before the fix).
2. **Minor, leak. PDF export printed the subject of an invisible template** (`Issue#to_s` in
   `issues_pdf_helper`).
   Resolution: fixed in `4e1817f`: an invisible or missing template is "#id" in the column and the
   group headers, the same key in both. Test `test_query_column_hides_what_the_user_cannot_see`
   (red before).
3. **Minor/major, performance. N+1 in the column** (an ancestor query per subtask, a `find_by` per
   template).
   Resolution: fixed in `4e1817f`: parents are walked once per ancestor per list and cached,
   templates (also missing ones) cached. Residual: one query per distinct ancestor not seen yet.
4. **Minor, performance. `issue_ids_by_template` evaluated the whole tree and ran several times per
   request.**
   Resolution: fixed in `4e1817f`: only the subtrees of the template and its recurrences are
   evaluated; each query memoises the filter SQL. Test
   `test_issue_ids_by_template_leaves_the_rest_of_the_tree_out`, `test_merge_ranges`.
5. **Minor. The module tab's Report link did not cover the same time as its totals** (subprojects,
   moved copies).
   Resolution: fixed in `4e1817f`: the link filters on exactly the tab's templates and goes to the
   global report when a series spans projects. Test `test_module_tab_report_link` (two series).
6. **Minor. Global lists showed filter values from projects without the module or permission.**
   Resolution: fixed for the filter values in `4e1817f` (`Project.allowed_to_condition`). The column
   on a global list still names the template of a visible issue in such a project; core shows the
   same relation as "Copied from", so not worth a second visibility rule in the SQL. Recorded in
   docs/SPENT-TIME.md.
7. **Minor, UI. Totals stale after adding or deleting a schedule by AJAX.**
   Resolution: not changed: time does not change by adding or deleting a schedule, a reload shows
   the numbers. Recorded in docs/SPENT-TIME.md.
8. **Minor. A template that is itself a recurrence stays in the series it recurred in.**
   Resolution: kept by design (its own work belongs to the occurrence it is), pinned by
   `test_template_that_is_a_recurrence_stays_in_its_series`, recorded in docs/SPENT-TIME.md.
9. **Tests that would pass with wrong code; gaps.**
   Resolution: fixed in `4e1817f`: a second series (`=` and `!` now differ from `*` and `!*`,
   several values), grouping with several groups and blank, copy_last, deleted template, invisible
   issues. PDF export: covered by the column test; no PDF test.
10. **Nit. init.rb comment; `initialize_available_filters` made protected.**
   Resolution: fixed in `4e1817f`: comment says prepend composes with plugins that prepend; methods
   stay public as in core's subclasses.
11. **Nit. A deleted template's id became nil in group keys and was looked up per row.**
   Resolution: fixed with 2 and 3 in `4e1817f`.
12. **Nit. `ORDER BY ... LIMIT 1` in a subquery does not run on SQL Server.**
   Resolution: not changed: GEOxyz runs PostgreSQL (Jan, 2026-10-07); works on PostgreSQL, MySQL
   and SQLite. Recorded in docs/SPENT-TIME.md.

Checked by the reviewer, nothing found: SQL injection, escaping, i18n, the membership rule across
copies, subtask copies, reopen, deleted schedules, moved and re-parented issues and nested series,
double counting, group keys on 5.1 and 7.0, prepend visibility, short filter syntax, authorization.
