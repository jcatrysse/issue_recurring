# Spent and estimated time of a recurring issue: analysis and plan

Written 2026-10-22 by the coordinating session for this feature, from the code of `master` and
`redmine70-migration`, Redmine core `5.1-stable` and `7.0-stable-GEOxyz`, and a measured SQL spike
on PostgreSQL 16 (`docs/spent-time/spike.sql`). Jan answered the open choices the same day (see
"Decided by Jan"); the build started in the same session. This file is the plan and the memory of
the work; update it as the work goes.

## Voor Jan

**Wat.** Een manager wil kunnen zien hoeveel tijd een terugkerende taak in totaal kost: het
oorspronkelijke issue plus alle herhalingen, ook per periode (deze maand, dit jaar, per maand naast
elkaar), per persoon en per activiteit, en geschat tegenover besteed.

**Het idee in een zin.** We bouwen geen eigen rapportscherm. We leren Redmine's eigen "Spent time"
een filter en een rapportcriterium "Recurrence of"; daarmee werken lijst, rapport per
maand/week/jaar, periodefilter, CSV-export en REST API meteen, precies zoals de gebruiker ze kent.
Het issue en de moduletab tonen het totaal en linken daarnaartoe.

**Waar het zichtbaar wordt.**
1. *Spent time* (lijst en rapport): filter "Recurrence of" en, in het rapport, "Recurrence of" als
   rij: een rij per terugkerende taak, kolommen per maand. Dat is het managersoverzicht.
2. *Het issue*: in het blok "Recurrences" een regel met besteed en geschat totaal over de hele
   reeks, de uren zijn een link naar de gefilterde Spent time-lijst. Op het origineel en op elke kopie.
3. *De moduletab "Issue recurrences"*: kolommen "Estimated time" en "Spent time" per taak, totalen
   bovenaan zoals core ze toont, en een link "Spent time" naar het rapport per maand.

**Impact.** Geen migratie, geen gem, geen instelling, geen nieuwe permissie, geen nieuwe route. Twee
core-klassen worden uitgebreid met `prepend` (`TimeEntryQuery`, `Redmine::Helpers::TimeReport`),
plus de twee bestaande views van de plugin. Beide klassen zijn op 5.1 en 7.0 voor dit doel gelijk,
dus dezelfde code draait op `master` en op `redmine70-migration`.

**Gemeten** (synthetische data, ruim groter dan wat we verwachten: 180.620 issues, 400 terugkerende
taken met 80.100 kopieen, 2 miljoen tijdregistraties): totaal op de issuepagina voor de grootste reeks
(1.176 issues) 23 ms; moduletab onder 0,2 s; rapport per maand over een jaar voor alle projecten
1,3 tot 1,7 s, waar core's eigen rapport per issue op dezelfde data 0,7 tot 0,8 s doet; per project
0,2 tot 0,8 s. De spreiding komt van PostgreSQL's JIT-compilatie (standaard aan), die bij onze
zwaardere queries zo'n 0,5 s kost; zie "Performance".

**Master en migratiebranch.** Je vraagt dit op beide. Dat wijkt af van je algemene beslissing van
2026-10-07 ("niets naar master, geen 5.1"); ik noteer het als bewuste uitzondering voor deze feature.
Kost: alles twee keer testen (Redmine 5.1 en 7.0) en de code mag niets gebruiken dat alleen in 7.0
bestaat. Voor deze feature is dat haalbaar zonder twee versies van de code.

**Jouw keuzes** van 2026-10-22 staan onderaan onder "Decided by Jan": C1 tot C4 volgens
aanbeveling, fase 2 meteen mee, eerst `master` en dan `redmine70-migration`.

## Status (2026-10-22, built)

Phases 1 and 2 are built, on both branches, with the same code apart from one test line
(`fixture_paths` on Rails 7.1+).

| | `spent-time-master` (from `master`, Jan merges it) | `redmine70-migration` |
|---|---|---|
| Feature commits | `39893d4` `c1b3c89` `ac9ce8f` `4138dbf` `c43bfae` `cc73f43` `4e1817f` | `d1aa81c` `f6a45dc` `7825dd5` `3b5f8ff` `0b36c13` `e56282b` `5461190` `e46c157` |
| Redmine measured on | 5.1-stable-GEOxyz (5.1.13, Rails 6.1, Ruby 3.2.6), PostgreSQL 16.15 | 7.0-stable-GEOxyz (Rails 8.1, Ruby 3.3.6), PostgreSQL 16.15 |
| Plugin tests before | 91 runs, 91 errors as `master` is; 91 runs, 9029 assertions, 0 failures after `6a17ef8` (below) | 106 runs, 10888 assertions, 0 failures, 0 errors |
| Plugin tests after | 134 runs, 9298 assertions, 0 failures, 0 errors (seed 57916) | 149 runs, 11193 assertions, 0 failures, 0 errors (seed 25970) |
| New tests | 43 (17 unit, 26 integration); 15 of the first 18 red without the feature, the 2 visibility tests red before the review fix | same 43 |
| End to end, real Redmine, production mode | `docs/e2e/redmine51/spent-time.md`: 14 screenshots, 0 problems; before: `docs/e2e/before/spent-time-before.md`, 11 screenshots (`master` without the feature) | `docs/e2e/spent-time.md`: 14 screenshots, 0 problems |
| Review | independent Claude review, 12 findings, all resolved: `docs/reviews/claude-2026-10-22-spent-time.md`; OpenAI review (gpt-5) of `d4815ee..5ad616c`: no findings, `docs/reviews/openai-2026-10-22-5ad616c.md` | same code |

Found on the way, outside this feature:
- `master`'s tests did not run at all on Redmine 5.1.13 (core declares `fixtures :all`; 91 errors);
  `6a17ef8` on `spent-time-master` resets the fixture list as `22fab85` does here. `master`'s
  migration tests left a recurrence with `count` NULL behind; `6523186` is this branch's `68d7e2a`.
- `master`'s rakefile boots the app in development, so `rake generate_secret_token` without
  `RAILS_ENV` fails on 5.1 (`LoadError listen`); fixed here in `03480ad`, worked around for the
  5.1 server by running it with `RAILS_ENV=production`.
- The intermittent test (decision q4) failed once in each of two full runs taken while a browser run
  loaded the machine: `test_renew_anchor_mode_fixed_one_issue_date_not_set`, "IssueRecurrence #253:
  Last issue is invalid; Issue #nil: Recurrence of is invalid; Issue #771942122: Recurrences is
  invalid", i.e. a recurrence of the original issue was itself invalid when the copy validated its
  `recurrence_of`. The same seed passes, the test alone passes 3 of 3, the following full runs on
  both branches were green. Not caused by this feature (it touches no validation); recorded for q4.

Known limits, by decision or as measured:
- A recurrence that gets schedules of its own stays in the series it recurred in; only its own
  recurrences form the new series (review finding 8, pinned by a test; decided by Jan, option A).
- After adding or deleting a schedule on the issue page or the module tab, the totals show their
  new state after a reload (finding 7; time itself does not change by it).
- On global lists the column "Recurrence of" also names the template of a visible issue in a
  project where the user may not view recurrences; core shows the same relation as "Copied from"
  (finding 6).
- The subquery with `ORDER BY ... LIMIT 1` does not run on SQL Server; PostgreSQL, MySQL and SQLite
  are fine (finding 12).

Deploying: no migration, no setting. `master`: restart Redmine after the merge. This branch: goes
live with the Redmine 7 upgrade as the rest of it.

## What we want

The user is a manager who wants to know what recurring work costs. The questions, in the order the
design answers them:

| # | question | answered by |
|---|---|---|
| Q1 | How much time did recurring task X cost in total, over every recurrence? | issue panel, module tab |
| Q2 | How much in a period: this month, this year, per month? | Spent time with filter, report columns month/week/year |
| Q3 | Which recurring tasks cost the most in a period, side by side? | Spent time > Report, rows "Recurrence of" |
| Q4 | Who spent it, on which activity? | same report, second criterion User or Activity (core) |
| Q5 | Estimated against spent, per recurrence and in total | issue panel, module tab; per recurrence in phase 2 |

Constraints, in Jan's order: performance; UI/UX as close to native Redmine as possible;
maintainability; usable by a manager, also over a period; on `master` and on `redmine70-migration`.

## How the plugin links issues today

- `issues.recurrence_of_id` (migration 002, indexed) points from a recurrence to the issue that
  carries the schedule, the **template**. `IssueRecurrence#create` sets `recurrence_of = self.issue`
  for the new issue and for every copied subtask (`app/models/issue_recurrence.rb`, both places).
  So every member of a series points to the same template, also with "copy last recurrence", where
  the copy is made from the last issue but still points to the template.
- Creation mode "reopen" reopens the template itself and sets `recurrence_of` on it as well: the
  template then points to itself (`test/e2e/seed.rb` clears exactly that self-reference).
- Copying an issue by hand clears `recurrence_of` (`CopyFromWithRecurrences`), deleting the template
  nullifies it on the copies (`dependent: :nullify`).
- The copy does not record *which* schedule made it. An issue with two schedules has one series; a
  breakdown per schedule would need a schema change and is not proposed.

**Definition used throughout: the series of template T** is T and every issue with
`recurrence_of_id = T`, each together with all its descendants, every issue counted once. That is
core's "Total spent time" (`Issue#total_spent_hours`: the issue and its subtasks), taken over every
recurrence. As built, every issue belongs to at most one series: a descendant that belongs to a
series of its own (edge case 5) counts there only, so no hour is ever counted in two series. A **template** is an issue that has a schedule or has recurrences pointing to it (a
template whose schedules were deleted still has its series).

## What Redmine core already offers (5.1 and 7.0)

Checked on `5.1-stable` and `7.0-stable-GEOxyz`:

- Issue page: "Estimated time: 4.00 h (Total: 7.00 h)" and "Spent time: 3.00 h (Total: 5.50 h)",
  the hours a link to `time_entries?issue_id=~ID` (`IssuesHelper#issue_spent_hours_details`); shown
  only with `view_time_entries`, estimated hidden when the tracker disables the field.
- `TimeEntryQuery`: filters are declared in `initialize_available_filters` and resolved by
  `sql_for_<field>_field` (e.g. `issue.parent_id`, which plucks ids and returns `issue_id IN (...)`).
  Identical on both versions for this purpose; 7.0 only adds `user.group`, `user.role` and the
  `:hour` filter type.
- `Redmine::Helpers::TimeReport#load_available_criteria`: a hash of criteria with `:sql`, `:klass`,
  `:label` and optional `:joins`. The report view and CSV export iterate it; a criterion with
  `klass: Issue` renders as a link to the issue (`TimelogHelper#format_criteria_value`). Identical on
  both versions apart from whitespace.
- Issue list totals of spent time apply `TimeEntry.visible_condition`; the issue page numbers do not.
- Nothing in core knows about recurrences, so there is nothing to reuse beyond the query machinery,
  and nothing here is a candidate for a core patch.

## Proposed design

### 1. Spent time filter "Recurrence of" (the backbone)

`TimeEntryQuery` gets the filter `issue.recurrence_of`, shown as "Issue's Recurrence of" (core's
`label_attribute_of_issue` with the existing plugin key `field_recurrence_of`), type `:list_optional`:

- values: the templates the user can see in the project and its subprojects (all visible templates
  in the global list), shown as `#12: Monthly backup check`;
- `is` / `is not`: time on the series of the chosen templates (multi-select works as in core);
- `any` / `none`: time on any series, or on none.

SQL follows core's own pattern, measured index-friendly: `is` plucks the member ids and their
subtrees and returns `time_entries.issue_id IN (...)`, like core's `issue.parent_id` filter; `any`
and `none` use a per-row `EXISTS` (an `IN` subquery over every member and subtree was measured at
1.2 s and is not used).

Everything core does with a filter then works unchanged: the list with totals, the Report tab
(filters are kept when switching tabs), the period filter "Date", CSV and Atom, saved queries,
`/time_entries.json?f[]=issue.recurrence_of&op[issue.recurrence_of]==&v[issue.recurrence_of][]=12`.

### 2. Spent time > Report criterion "Recurrence of"

`TimeReport` gets the criterion `recurrence_of` (label "Recurrence of"), `klass: Issue`, so each row
is a link to the template, with core's period columns, totals and CSV. Its `:sql` gives every time
entry the template of its series:

```sql
CASE
  WHEN issues.recurrence_of_id IS NOT NULL THEN issues.recurrence_of_id
  WHEN EXISTS (schedule on issues.id) OR EXISTS (recurrence pointing to issues.id) THEN issues.id
  WHEN issues.parent_id IS NOT NULL THEN (nearest ancestor that is a member: its template)
END
```

Measured: doing the ancestor lookup only for subtasks costs less than half of a plain correlated
subquery (1.3 to 1.7 s against 3.6 s for a year over all projects), and both give identical sums per
series (0 mismatches over 21 series). The report row of a series equals the filter total of that
series.

### 3. Issue page: one line in the Recurrences panel

In `app/views/issues/_issue_recurrences_hook.html.erb`, under "This is a recurrence of", for the
template and for every recurrence:

```
Recurrences                                                                  + Add
This is a recurrence of #12: Monthly backup check
All recurrences (13 issues): Estimated time 52.00 h, Spent time 47.25 h
<existing table of schedules>
```

- "Spent time 47.25 h" is a link to the Spent time list filtered on this series, the same way
  core's own "Spent time" links to `time_entries?issue_id=~ID`. Project-scoped path, global path when
  the series spans projects (core does the same for cross-project subtasks).
- Format with core's `l_hours_short`; every word is a core key that en, es and bg already
  translate (`label_total`, `label_x_issues`, `field_estimated_hours`, `label_spent_time`), so the
  feature adds no locale key at all. As built: "Total (3 issues): Estimated time: 9.00 h, Spent
  time: 14.50 h". The count is the template and its recurrences; subtask copies are part of their
  recurrence and not counted separately.
- Spent time only with `view_time_entries` (as core); estimated time hidden when the template's
  tracker disables `estimated_hours` (as core). The panel itself stays behind `view_issue_recurrences`.
- Shown only when the issue belongs to a series. Computed by the helper
  (`IssuesHelperPatch#recurrence_series_totals`, like core's own helpers call
  `issue.total_spent_hours`) in a fixed number of queries, never per recurrence in Ruby.

### 4. Module tab "Issue recurrences"

In `app/views/issue_recurrences/index.html.erb`:

```
Issue recurrences                                                        Spent time
Estimated time: 310.00 h   Spent time: 288.50 h
Issue                      | Every   | Last  | ... | #  | Estimated time | Spent time
#12: Monthly backup check  | 1 month | #345  | ... | 12 |        52.00 h |    47.25 h
#40: Weekly site report    | 1 week  | #351  | ... | 40 |        80.00 h |   101.00 h
```

- Two columns at the end, right-aligned like core's `hours` cells; Spent time is a link to the
  filtered list. Totals above the table in core's `query-totals` markup.
- One grouped computation for all series of the page (measured under 0.2 s for 20 series, 3,998
  issues, 44,537 entries), not one per row.
- A schedule list can show the same issue twice (two schedules): rows sorted by issue, the numbers
  on the first row of that issue only, so the totals never count a series twice.
- The contextual link "Report" (core's `label_report`; "Spent time" next to the totals read as a
  duplicate in the browser run) opens Spent time > Report with the
  filter "Recurrence of: any", rows "Recurrence of", columns per month and "Date: less than 365 days
  ago". That one link answers Q2 to Q4, with core's own period controls.

### Phase 2 (built together with phase 1, Jan C5)

- Issue list: filter and column "Recurrence of" on `IssueQuery`. Filtered on one template, with
  core's columns Start date, Due date, Estimated time, Spent time and their totals, this is
  "estimated against spent per recurrence" (Q5 per recurrence), and with filters on start/due date
  it answers "which recurrences fell in Q3", by issue date instead of by date of logging.
- Spent time list: column "Recurrence of", groupable (group totals come with core).

### Deliberately not built

An own report page, period selector, chart or CSV (core has them); a cache or a denormalised column
(measured unnecessary, and a migration plus a backfill to keep correct on every move); a breakdown
per schedule (needs a schema change); "Estimated remaining time" (exists only in 7.0, would split
the code between the branches); icons on the new links (`sprite_icon` exists only in 7.0; core's own
spent time link has no icon either).

## Permissions and visibility

- Spent time sums use `TimeEntry.visible`, so a role limited to "own time entries" sees its own
  hours, and the number shown equals the total on the list it links to. Core's issue page does the
  same (`IssuesController#show` calls `Issue.load_visible_total_spent_hours`); the analysis said
  otherwise, the browser run showed core's "Total: 6.50 h" next to the series' 13.00 h, both counting
  only the manager's own entries.
- Estimated sums use `Issue.visible` (core's `total_estimated_hours` does the same).
- Filter, criterion and columns only where the user has `view_issue_recurrences` (in the project,
  or in any project for the global list) and the project has the module enabled. The filter values
  list only visible templates. No new permission.

## Edge cases the tests must cover

1. Copy, copy last, reopen (template points to itself: one issue, split only by date).
2. Including subtasks: subtask copies point to the template and sit below a recurrence; counted once.
3. Subtasks of the template that are not copied, and subtasks added by hand below a recurrence:
   counted, as in core's total.
4. Schedules deleted, recurrences kept: still a series. Template deleted: the series is gone
   (`recurrence_of` nullified by the plugin today), time stays on the issues.
5. A series nested in another (a recurring subtask with its own schedule below a recurring parent):
   it belongs to the innermost series only, in the filter, the report, the columns and the totals
   alike, so the totals of the module tab add up. The outer series' total is then lower than core's
   "Total" on its issue page, which counts the subtask too; rare, and the price of never counting
   an hour twice.
6. A recurrence moved to another project or a private project: visibility decides, link goes global.
7. Time on the project without an issue: never part of a series.
8. Recurrences created ahead (setting "Renew ahead"): they carry estimated time but no spent time yet,
   so the estimated total includes planned work. The panel says "Estimated time", not "remaining".
9. Roles: manager, reporter without plugin permissions, outsider, "own time entries only",
   `view_time_entries` absent, module off, tracker without estimated time.

## Performance (measured 2026-10-22)

PostgreSQL 16.15 in this container, synthetic data in `docs/spent-time/spike.sql`: 180,620 issues,
400 templates (40 with three subtasks), 80,100 recurrences including subtask copies, 2,000,000 time
entries over three years, Redmine's own indexes (`issues(root_id, lft, rgt)`, `recurrence_of_id`,
`time_entries(issue_id)`, `(project_id)`; core has no index on `spent_on`). Without Redmine's
visibility clause, which core's own queries pay as well.

Times are `EXPLAIN ANALYZE` execution times over repeated runs, first with PostgreSQL's defaults
(`jit = on`, as GEOxyz most likely runs), then with `jit = off`. The time entries are random, and the
set was generated twice (the file was rerun end to end as a check), so entry counts differ slightly
between rows.

| what | entries in scope | default | `jit = off` |
|---|---|---|---|
| Issue panel, largest series (1,176 issues): spent sum | 12,815 | 23 ms | |
| Issue panel, same series: estimated sum | | 12 ms | |
| Module tab, 20 series of one project (3,998 issues), stepwise: ids, then `IN` | 44,537 | under 0.2 s | |
| Module tab, one SQL statement with `OR`-join (rejected) | 44,537 | 0.8 to 1.2 s | |
| Report per month, 2025, all projects, criterion "Recurrence of" | 666,717 | 1.5 to 1.7 s | 1.3 s |
| Same, core criterion "Issue" (baseline) | 666,717 | 0.7 to 0.75 s | 0.8 s |
| Same, plain correlated subquery (rejected) | 666,717 | 3.6 s | |
| Report per month, 2025, one project, criterion "Recurrence of" | 33,323 | 0.75 to 0.8 s | 0.23 s |
| Same, core criterion "Issue" (baseline) | 33,323 | 0.09 to 0.18 s | 0.10 s |
| Filter "any", one project, last 365 days | 31,191 | 0.44 to 0.63 s | 0.19 s |
| Filter "any", all projects, last 365 days | 625,838 | 0.7 to 0.79 s | 0.47 s |

Finding: the subqueries raise the planner's cost estimate above `jit_above_cost`, and the JIT
compilation then costs about 0.5 s, more than the query itself on one project (the plan of the
per-project report says `JIT: ... Total 475.722 ms` of 719 ms execution). Core's own report
showed no such penalty here. Nothing in the plugin should switch JIT off (PostgreSQL-specific, and a
server decision); whether production runs with `jit = on` is one line to check
(`SHOW jit;`), and many installations turn it off for web workloads. The implementation session
measures through Redmine and records both.

GEOxyz' real volume is unknown here; three counts on production calibrate it
(`SELECT count(*) FROM issues`, `... FROM time_entries`, `SELECT count(DISTINCT issue_id) FROM
issue_recurrences`). The synthetic set is meant as an upper bound.

## Impact

| | |
|---|---|
| Schema, gems, settings, routes, permissions | none |
| Core classes extended | `TimeEntryQuery` (filter), `Redmine::Helpers::TimeReport` (criterion), both with `prepend` (Jan, 2026-10-07); `IssueQuery` only in phase 2 |
| Plugin files changed | `init.rb` (five patch lines), `IssueRecurrencesController#index`, `IssuesHelperPatch`, `IssueRecurrencesHelper`, the panel and module tab views |
| New plugin files | `app/models/issue_recurrence_series.rb`; `lib/issue_recurring/` `time_entry_query_patch.rb`, `time_report_patch.rb`, `issue_query_patch.rb`, `recurrence_of_column_patch.rb`, `recurrence_of_query_column.rb`; tests; `test/e2e/spent-time.mjs` |
| Size, as built | 371 lines of code and views; 475 lines of unit and integration tests; a 206-line e2e scenario |
| Risk: other plugins | other GEOxyz plugins may patch the same two classes; `prepend` composes, the combined run with all GEOxyz plugins must show the filter and the report still work |
| Risk: core upgrades | `TimeReport#load_available_criteria` is private API, unchanged between 5.1 and 7.0 apart from whitespace; a test pins the criterion so an upgrade that breaks it fails loudly |
| Locales | none changed: every label is an existing key (core's, or the plugin's `field_recurrence_of`) |

## Both branches

- One design, the same code: no 7.0-only API (no `sprite_icon`, no `:hour` filter type, no
  estimated remaining time). The few lines where `master` and `redmine70-migration` already differ
  (`init.rb`) are adapted, not branched in code.
- Order (Jan, 2026-10-22): `master` first, on Redmine 5.1 (Ruby 3.2, since 5.1 refuses 3.3), with
  the `.codex` harness of `redmine70-migration` copied next to the code and not committed; then the
  same commits on `redmine70-migration`, proven on Redmine 7.0-stable-GEOxyz.
- `master` is the default branch and is never pushed to directly (plugin rule): the work goes to a
  branch from `master` and Jan merges it into `master` himself (Jan, 2026-10-22).
- `redmine70-migration`: pushed directly, after every commit, as during the migration (Jan, 2026-10-22).
- Exception to Jan's general decision of 2026-10-07 ("nothing to `master`, no 5.1"): asked by Jan on
  2026-10-22 for this feature. Record it under "Decided by Jan" in `docs/REDMINE7-MIGRATION.md` when
  the feature is built.

## Definition of done

The gates of `docs/REDMINE7-MIGRATION.md` ("Rules", "Definition of done"), for this feature, on
both branches:

- Unit and integration tests for every edge case above, each failing without the change; the full
  plugin suite green on 7.0-stable-GEOxyz and on 5.1-stable, numbers in this file.
- End to end on a real Redmine (`.codex/start_server.sh`, `.codex/e2e.sh`), new scenario
  `test/e2e/spent-time.mjs`: panel line, module tab columns and link, filter in list and report, CSV,
  REST, as admin, manager, reporter, outsider and a role with "own time entries only"; before pictures
  on the current production branch. Screenshots looked at, committed in `docs/e2e/`, listed in the
  inventory of `docs/REDMINE7-MIGRATION.md`.
- Measurements through Redmine (issue page, module tab, report) on the e2e seed scaled up.
- Combined run with the other GEOxyz plugins: no new failure.
- Own adversarial review, and `.codex/openai_review.sh` when `OPENAI_API_KEY` is set.

## Decided by Jan

Answered by Jan on 2026-10-22, one question at a time, with the options, an explanation and the
recommendation in front of him:

- C1: **A**, a line in the Recurrences panel.
- C2: **A**, "Recurrence of".
- C3: **A**, all-time totals on the module tab, the link opens core's report.
- C4: **A**, subtasks count, like core's "Total".
- C5: **B**, phase 2 is built now, together with phase 1.
- Order: `master` first, then `redmine70-migration`.
- `master`: Jan merges it himself from a branch. `redmine70-migration`: pushed directly.
- On `master` at all: asked by Jan for this feature, an exception to his general decision of
  2026-10-07 ("nothing to `master`, no 5.1").
- After the build, same day: a recurrence that gets schedules of its own stays in the series it
  recurred in, only its own recurrences form the new series: **A** (as built, pinned by
  `test_template_that_is_a_recurrence_stays_in_its_series`). The alternative was B, its own time
  moves to the new series.

The options as they were put to him:

- **C1, where on the issue page.** A) A line in the plugin's "Recurrences" panel. B) A row next to
  core's "Spent time" in the issue attributes. *Recommended: A*: all recurrence information stays
  together behind the plugin's permission, and the panel is the plugin's own markup, while B would copy
  core's attribute markup into a hook that renders after the custom fields.
- **C2, the name.** A) "Recurrence of", the existing plugin key (already translated, matches "This is
  a recurrence of"). B) A new name such as "Recurring task" or "Series". *Recommended: A*: no new
  translations to invent, and it reads right in the report ("Recurrence of: #12 Monthly backup check").
- **C3, period on the module tab.** A) All-time totals on the tab, the link opens core's report with
  its own period filter. B) A period selector on the tab itself. *Recommended: A*: native controls,
  no second period UI to build and maintain.
- **C4, subtasks.** A) Count subtasks of every recurrence, like core's "Total". B) Count only the
  issues of the series themselves. *Recommended: A*: otherwise the series total is lower than the sum
  of the totals on the issue pages.
- **C5, phase 2.** A) Later, separate. B) Now, with the rest. *Recommended: A*: phase 1 answers Q1 to
  Q4 and most of Q5; phase 2 is worth it once managers use phase 1.

## Prompt for a session that continues this work

> Read CLAUDE.md, docs/REDMINE7-MIGRATION.md and docs/SPENT-TIME.md, then continue phases 1 and 2
> of docs/SPENT-TIME.md with Jan's decisions recorded there: `master` first (a branch Jan merges),
> then the same commits on `redmine70-migration`. Same gates as the migration: tests on PostgreSQL, every function end to end in a browser
> with and without permissions, measurements through Redmine, the combined run, the OpenAI review when
> the key is set. Push after every commit. Report to me in Dutch at the end.
