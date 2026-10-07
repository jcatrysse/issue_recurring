# Redmine 7 migration: issue_recurring

Start a Claude Code (or Codex) session on this repository, branch `redmine70-migration`, with:

> Read CLAUDE.md and docs/REDMINE7-MIGRATION.md, then carry out the Redmine 7 migration of this
> plugin as described there, on branch redmine70-migration. That includes the plugin's tests on
> PostgreSQL (MariaDB no longer required, Jan 2026-10-07), every function exercised end to end on a real running Redmine in a
> browser (with and without permissions, failure paths included) with screenshots you looked at,
> and an OpenAI review of the diff when OPENAI_API_KEY is set. Report to me in Dutch at the end.

This file is the plan and the memory of that work. Update it as you go: verdicts, results,
what is left. Written 2026-10-06 from a measured analysis (report at the bottom).

## Status

| | |
|---|---|
| Plugin id | `issue_recurring` |
| GEOxyz runs today | `master` |
| Upstream | cryptogopher/issue_recurring (master 19d3997, 2024-08-11; inactive, R6 ticket #50 unanswered) |
| Runs on Redmine 7 as is | NEE (master); JA on this branch |
| Upstream sync | UPSTREAM DOOD |
| After sync | n.v.t. |
| Complexity (1 trivial .. 5 rewrite) | 2 |
| Measured on | Redmine 7.0.1 (7.0-stable-GEOxyz), Rails 8.1.3.1, Ruby 3.3.6, PostgreSQL 16.15 (MariaDB 10.11.14 before Jan's decision of 2026-10-07) |
| Migration session | 2026-10-06/07, done; Jan's decisions of 2026-10-07 built the same day (see "Decided by Jan"). Tests and e2e green on PostgreSQL, alone and with 15 other GEOxyz plugins; one intermittent test error still under observation (decision q4) |
| Version | `1.8.0-geoxyz` (decision q3) |
| Branch head when this file was last updated | see `git log` (the commit that changes this file) |
| Deploy | `redmine70-migration` goes live with Redmine 7; nothing is cherry-picked to `master` (Jan, 2026-10-07) |

## Already on this branch

Before the session: `59879c4` (IssueRecurrence loads and renders on Rails 8.1), `22fab85` (plugin
fixtures only on Rails 7.1+). Session commits, in order:

| commit | what |
|---|---|
| `cbb662a` | `.codex/test_setup.sh`: PostgreSQL role creation as root (tooling) |
| `dcf1c89` | Work item 1: schema patches for Rails 7.1+ (`Schema::Definition`, `pool.schema_migration`) + `test/unit/schema_test.rb` |
| `68d7e2a` | Migration tests leave the database as they found it (78 order-dependent failures otherwise) |
| `03480ad` | Work items 2 and 3: rakefile no longer boots the app; `redmine:plugins:test:migration` on Rails 7.1+ |
| `de5bf97` | Work item 4: edit/delete icons through `sprite_icon` + test |
| `a1e6586` | Flaky `test_renew_applies_journal_mode_configuration_setting` made order-independent |
| `c96b054` | GEOxyz 241424b follow-up: success notices shown again, scoped to the plugin's JS responses + test |
| `f915734` | GEOxyz e6fae03 bug: reopen renewals deleted the issue's own relations + test |
| `7649185` | Webhooks: `renew_all` waits for queued webhook jobs (`:async` adapter) + test |
| `408c64c` | UX: Add link of the panel with the core `add` icon + test |
| `12b28af`, `7610e14`, `0ae8281`, `87c1c81` | E2E scenarios, seed, screenshots (PostgreSQL, MariaDB, before on 5.1) |
| `b953bc5` | CHANGELOG, README compatibility row |
| `6aa1a18` | OpenAI review report (no findings) |
| `3e0926a` | `test_renew_even_when_issue_author_has_no_permission_granted` made deterministic (3 random failure cases, pre-existing) |
| `ded1808`, `3bee62c` | plan results, second OpenAI review |
| `8aea260` | Jan's decisions of 2026-10-07 (`docs/DECISIONS-2026-10-07.md`, by the coordinating session) |
| `75ccd29` | General decision: `Issue#copy_from` patched with `prepend` instead of `alias_method` + `test/unit/issue_patch_test.rb` |
| `2c02ee0` | Decision q3: version `1.8.0-geoxyz` + `test/unit/plugin_test.rb` |
| `85dfd89`, `edf0dcc` | Decision q4: the `renew_all` test helper names the errors behind "Last issue is invalid", following invalid associations + `test/unit/renew_helper_test.rb` |
| `fd6e793` | General decision: Redmine 5.1 fallbacks added on this branch removed |
| `b1d16e0` | Found by the new e2e refusal path: an issue copy by a user without recurrence permissions failed with "Recurrences is invalid"; now copied without the recurrences + integration test |
| `3e3c0a3` | Follow-up after the OpenAI review: the copy keeps exactly the recurrences whose own `editable?` check passes + integration test |
| `e5c9088` and later | e2e (copy-issue for all users, plugin-version, combined run), plan, reviews |

## Work list for the migration session

1. DONE `dcf1c89`. Schema patches rewritten for Rails 7.1+: prepend on `ActiveRecord::Schema::Definition`
   (falls back to `ActiveRecord::Schema`), `pool.schema_migration.create_table`. Measured: after
   `db:test:prepare` the plugin's versions were `[]` before, `1..8` after. The 3 MigrationsTest errors
   are gone. While doing this, found that the migration tests left the DB at version 2 with
   `count = NULL` rows when they ran before the other tests in one process: fixed in `68d7e2a`.
2. DONE `03480ad`. `redmine:plugins:test:migration` uses `run_from_rake` (core's way), `rake_run` where it
   still exists. Before: `NoMethodError rake_run`; after: 3 runs, 0 failures, 0 errors.
3. DONE `03480ad`. `require_relative config/environment` removed. `rake -T` 3.5 s -> 2.6 s. Seen live on
   5.1 + master: `rake generate_secret_token` without RAILS_ENV aborted with `LoadError listen` because
   the plugin's rakefile booted the app in development.
4. DONE `de5bf97`, `408c64c`. Edit, delete and add links use `sprite_icon` (plain label where it does not exist).
5. NOTED. The branch needs Rails >= 7.0; deploy only with the Redmine 7 upgrade (also in CHANGELOG).
6. DONE. Tests on Redmine 7.0-stable-GEOxyz: see "Results". 5.1-stable: not run for this branch, it
   cannot run there (item 5); 5.1 was used only for the before pictures with `master`.
7. DONE. Webhooks: see "Webhooks". One fix (`7649185`).
8. DONE. Every function end to end in a browser, see "Inventory" and "Results".

Extra, found during the session (not in the analysis):

- Reopen renewals deleted relations (GEOxyz e6fae03), fixed `f915734`; production data may be affected,
  see "After the upgrade".
- Success notices invisible since GEOxyz 241424b, fixed `c96b054`.
- `test_renew_applies_journal_mode_configuration_setting` was order-dependent (analysis called it flaky),
  fixed `a1e6586`.
- `test_renew_even_when_issue_author_has_no_permission_granted` failed on some random configurations
  (no dates, `count_limit` 0, a weekend start date in a `*_wday` mode), fixed `3e0926a`: 800 repetitions
  green, before about 1 failure in 150.

## GEOxyz changes to review or re-apply

| commit | date | subject | verdict |
|---|---|---|---|
| `e6fae03` | 2025-10-31 | Feature: add an option to copy issue relations in recurrence | KEEP, with a fix: for creation mode "reopen" the new issue is the issue itself, and the step that removes unselected relation types from the new issue deleted the issue's own relations (default setting: all of them). Measured on 5.1 + master: relations 1 -> 0 after one reopen. Fixed in `f915734` (relation copying only when a copy is made), test added. Code otherwise sound: settings sanitised against `IssueRelation::TYPES`, settings helper escapes labels, unit and integration tests present; the core "copied to" link of a copy survives with and without selected types (checked). |
| `241424b` | 2025-06-18 | Defect: issue_recuurent throws an error on the Custom Fields page #6165 | KEEP the removal of `layouts/base.js.erb` (it replaced the layout of every JS response in Redmine). Side effect fixed in `c96b054`: that layout was the only thing showing the plugin's notices "New issue recurrence created/updated/deleted"; they are now rendered by the plugin's own `create.js`/`destroy.js`, only on success. Before pictures (`docs/e2e/before/`) show the missing notice on today's production. |

## Inventory of functions

Taken from README, `init.rb` (module, 2 permissions, menu, settings), routes, the view hook, patches,
rake tasks. Scenarios in `test/e2e/`, screenshots and tables in `docs/e2e/<scenario>.md`.

| function | how a user reaches it | scenario | screenshots |
|---|---|---|---|
| Recurrences panel on the issue page (hook `view_issues_show_description_bottom`, `view_issue_recurrences`) | issue page | `issue-panel.mjs` | `issue-panel-*` (manager, admin, reporter hidden, outsider 403, module off/on) |
| Add a recurrence (`new`/`create`, `manage_issue_recurrences`) | panel > Add | `add-recurrence.mjs` | `add-recurrence-*` (form, invalid date limit, created with notice/icons, reload, reporter 403, outsider 403) |
| Edit a recurrence (`edit`/`update`) | panel > Edit | `edit-recurrence.mjs` | `edit-recurrence-*` (form, invalid multiplier, updated, reporter 403 and PATCH 403, 404) |
| Delete a recurrence (`destroy`) | panel > Delete | `delete-recurrence.mjs` | `delete-recurrence-*` (reporter DELETE 403, deleted with notice) |
| Project tab "Issue recurrences" (`index`, menu item) | project menu | `project-recurrences.mjs` | `project-recurrences-*` (list, empty state, delete from list, reporter no tab + 403, outsider 403, anonymous to login, unknown project 404) |
| Plugin settings (author, keep assignee, journal mode, copy recurrences, copy relation types, renew ahead) | Administration > Plugins > Configure | `plugin-settings.mjs` | `plugin-settings-*` (defaults, negative refused by form, saved, hand-made POST with unknown values stored as defaults, manager 403) |
| Renewal: cron `rake redmine:issue_recurring:renew_all` (copies, reopen, "recurrence of", mails, webhooks, copy relations, journal on reopen, second run idempotent) | cron | `renew.mjs` | `renew-*` |
| Copy recurrences on issue copy (setting), copies never keep "recurrence of"; `Issue#copy_from` patched with prepend | issue > Copy | `copy-issue.mjs` | `copy-issue-*` (setting off/on, copy of a recurrence, admin, reporter refused without copy_issues, reporter with copy_issues: copy without recurrences, outsider 403) |
| Plugin version 1.8.0-geoxyz (decision q3) | Administration > Plugins | `plugin-version.mjs` | `plugin-version-*` (admin, manager/reporter/outsider 403) |
| REST API: none of its own; core issue API with a recurrence, plugin route not an API | API | `rest-api.mjs` | `rest-api-issue-json.png` |
| Migrations 001-008, down and up | `redmine:plugins:migrate` | command | see "Results" |
| Dev task `redmine:plugins:test:migration` | rake | command | see work item 2 |

Not testable here: nothing; the plugin uses no IdP, LDAP, OAuth or mail server (mail goes to files).

## Results (2026-10-06)

Baseline, before any change (branch head `06fc75b`, Redmine 7.0-stable-GEOxyz, PostgreSQL):
unit + integration in one process 88 runs, 0 failures, 0 errors; migration tests 3 runs, 3 errors
(DuplicateTable, the schema patch); all files in one process (as `.codex/test_plugin.sh` runs them)
91 runs, 79 failures, 1 error, depending on the order (the migration tests corrupted the DB for the
tests after them). Smoke 14 pages and core flows 6 screenshots: 0 problems.

After, plugin tests (`.codex/test_plugin.sh`, all files in one process, random order):

| database | result |
|---|---|
| PostgreSQL 16.15 | final at `3e0926a`: 97 runs, 10785 assertions, 0 failures, 0 errors (seed 20480); 10 further full runs before it at the same code also green; see Open question 6 |
| MariaDB 10.11.14 | final at `3e0926a`: 97 runs, 10785 assertions, 0 failures, 0 errors (seed 55274); earlier runs 96 and 97 runs green |
| PostgreSQL with redmine_custom_workflows, redmine_subtask, redmine_issue_templates (`redmine70-migration`) | 6 full runs: 5 x 97 runs 0 failures 0 errors, 1 run 1 error (same intermittent error as above, not caused by these plugins) |

Migrations 001-008 down to 0 and up again on PostgreSQL and MariaDB: 8 reverted (table and
`issues.recurrence_of_id` gone), 8 migrated (back, 8 versions recorded). Boot and eager load in
production mode: `start_server.sh` (production) on both databases without errors.

End to end, Redmine 7.0-stable-GEOxyz in production mode, fresh database each time:

| run | smoke | core | plugin scenarios | problems |
|---|---|---|---|---|
| PostgreSQL (`docs/e2e/`) | 14 | 6 | 9 scenarios, 40 screenshots | 0 |
| MariaDB (`docs/e2e/mariadb/`) | 14 | 6 | 9 scenarios, 40 screenshots | 0 |
| PostgreSQL + the 3 plugins above (not committed) | 14 | 6 | 9 scenarios, 40 screenshots | 0 |
| Before: Redmine 5.1-stable + `master` (`docs/e2e/before/`) | - | - | 6 scenarios, 30 screenshots | 7, all expected: no notice after add/edit/delete, icons as CSS not SVG |

Every screenshot of the PostgreSQL run was opened and looked at; MariaDB and before spot-checked.

### After Jan's decisions (2026-10-07, PostgreSQL 16 only)

| run | result |
|---|---|
| Plugin tests alone, final at `3e3c0a3` | 104 runs, 10881 assertions, 0 failures, 0 errors (seed 45164) |
| Plugin tests with 15 other GEOxyz plugins (`redmine70-migration` of custom_workflows, subtask, issue_templates, parent_child_filters, issue_view_columns, inline_edit_issues, tint_issues, depending_custom_fields, project_workflows, extended_api, issue_field_visibility, itil_priority, checklists, tags; without view_issue_description, see below) | final at `b1d16e0`: 103 runs, 0 failures, 0 errors (seed 27689); 8 more runs at `edf0dcc`: 102 runs, 0 failures, 0 errors each; the first run at `85dfd89` hit the intermittent error once (decision q4) |
| With redmine_view_issue_description added | 26 failures: that plugin refuses issue show/update (403) without its new permission `view_issue_description`, which this plugin's test fixtures do not grant, so the test helpers' issue updates are refused. Not a defect of either plugin; a fixture/role matter |
| e2e alone (`docs/e2e/`, fresh database) | smoke 14, core 6, 10 plugin scenarios 54 screenshots, 0 problems |
| e2e with all 16 plugins (`docs/e2e/combined/`, fresh database) | 74 screenshots, 8 problems, none from this plugin: Project > Settings HTTP 500 from `redmine_depending_custom_fields` (`undefined method dcf_relevant_custom_fields` in its own settings tab; the same 500 with issue_recurring removed); issue pages 403 for reporter and the issue JSON 403 for manager from `redmine_view_issue_description` (its permission is not granted to the seeded roles) |
| Jan's check: Project > Settings, issue list, issue page with the other plugins | with all plugins but depending_custom_fields: admin and manager get 200 on `/projects/e2e-project/settings`, `/projects/e2e-project/issues`, `/issues/7` and the recurrences tab |

## Webhooks

Redmine 7 sends `issue.created`/`issue.updated` from model callbacks, so issues created or reopened by
`renew_all` trigger webhooks with core's payload; the plugin adds no issue data to the API or the
payload, so nothing to make consistent there. One real problem: the cron task runs with the production
default `:async` job adapter, the jobs run on threads of the rake process, and rake exited before the
last ones ran: 4 copies, 3 `issue.created` received. Fixed in `7649185` (wait for the adapter at the
end of the task); after: 4 of 4, plus `issue.updated` for the reopened issue (`renew.mjs`, receiver on
a non-loopback address because Redmine refuses loopback targets).

## Review

- Own review of the whole diff `e6fae03..HEAD`: nothing left open. Notes: `html_safe` in
  `IssueRecurrence#to_s`, `last_recurrence`, `next_recurrences` only wraps locale strings, numbers,
  dates and `link_to` output, no user input (pre-existing, unchanged). After `renew_all` shut down the
  `:async` adapter, later jobs in the same rake process run in the caller thread (executor fallback), so
  chaining tasks still works.
- OpenAI review (`.codex/openai_review.sh e6fae03`, gpt-5, 34 files): no findings
  (`docs/reviews/openai-2026-10-06-b953bc5.md`); again at `ded1808` (all session commits): no findings (`docs/reviews/openai-2026-10-06-ded1808.md`).
- After Jan's decisions (range `3bee62c..e5c9088`, gpt-5): one finding, on the new issue-copy hook
  (keep recurrences with manage permission alone). Not done as proposed (the recurrence's own
  validation needs more), but it showed the hook only partly repeated that check: fixed in `3e3c0a3`
  with a test; Resolution in `docs/reviews/openai-2026-10-07-e5c9088.md`. Second pass
  (`3bee62c..a297523`): no findings. My own review of these commits: nothing else open; the new hook
  also helps project copies into a project without the module (that issue copy failed before).

## Findings outside this plugin

- Redmine core 7.0-stable-GEOxyz: core's own rake tasks that create issues (`redmine:email:receive_imap`,
  `receive_pop3`, `receive`) have the same lost-webhook problem under the `:async` adapter. Not fixed
  here; for GEOxyz either a real job backend (`config.active_job.queue_adapter` in
  `config/additional_environment.rb`) or a core fix.
- `.codex/e2e.sh` also runs `test/e2e/helpers.mjs` as a scenario (it does nothing); harmless.

## Decided by Jan

Answered by Jan on 2026-10-07 in the coordinating session (recorded in `docs/DECISIONS-2026-10-07.md`).

General, for every GEOxyz plugin:
- Straight to Redmine 7, no backports to 5.1; nothing is cherry-picked to the default branch or to
  the branch production runs today. 5.1 compatibility is no longer a requirement. Done here: the 5.1
  fallbacks this branch had added are removed (`fd6e793`); the rules below are updated.
- PostgreSQL 16 only (GEOxyz uses no MariaDB/MySQL). Tests and e2e run on PostgreSQL; the earlier
  MariaDB runs stay as history (`docs/e2e/mariadb/`), MariaDB-only problems would be a note, not a blocker.
- deface without a version constraint: this plugin does not use deface, nothing to do.
- A core method other plugins also patch is patched with `prepend`, never `alias_method`: this
  plugin chained `Issue#copy_from` with `alias_method`; now `prepend` (`75ccd29`), with a test.
  Project > Settings, the issue list and an issue page answer 200 with 15 other GEOxyz plugins
  installed (see "Results").
- GitHub Actions stay manual only: unchanged (`workflow_dispatch` only).

For this plugin:
1. issue_recurring-q1, lost relations in production: Jan chose B, "Het verlies aanvaarden" (Geen werk,
   maar de gewiste relaties tussen issues blijven weg.). Recorded; no restore. The code fix stays (`f915734`).
2. issue_recurring-q2, real job backend for all of Redmine: Jan chose A, "Alleen de plugin-fix, de
   rest later apart bekijken" (Deze plugin verliest geen webhooks meer; de mailtaken van Redmine zelf
   kunnen dat nog wel, als webhooks gebruikt worden.). The plugin fix stays (`7649185`); the core mail
   tasks stay a finding outside this plugin.
3. issue_recurring-q3, version: Jan chose B, "1.8.0-geoxyz" (Toont duidelijker dat het een eigen
   GEOxyz-versie is.). Done in `2c02ee0` (init.rb, CHANGELOG, README), with a test.
4. issue_recurring-q4, the intermittent test: Jan chose A, "Zo laten, bij de volgende keer meer info
   verzamelen" (Geen werk nu; duikt de fout weer op, dan wordt de foutinformatie van het issue afgedrukt
   om de oorzaak te vinden.). Built in `85dfd89`/`edf0dcc`: the `renew_all` test helper now adds the
   errors behind "Last issue is invalid". It caught the failure on its first run with the other
   plugins: "Last issue is invalid (... Recurrence of is invalid)", i.e. the original issue the copy
   points to is the invalid record; the helper now follows that association too. Status of the
   next occurrence: see "Results".

Earlier recommendations taken over without a separate question: success notices kept (`c96b054`),
merge only with the Redmine 7 upgrade (now the general decision).

## Open questions for Jan

1. Copying an issue without recurrence permissions (`b1d16e0`, found by the new e2e refusal path):
   with "Copy recurrences on issue copy" on, a user who may copy issues but has no recurrence
   permissions could not copy at all ("Recurrences is invalid"), pre-existing since upstream. Built:
   the copy is made without the recurrences the user may not create (`b1d16e0`, `3e3c0a3`). Options: (A) this, recommended, nobody loses anything;
   (B) copy the recurrences anyway without checking the permission (lets a user create recurrences
   they may not manage); (C) refuse the copy as before.

## After the upgrade (production)

Actions the person doing the upgrade must take, or know about, for this plugin:

- Deploy this branch only together with Redmine 7 (it does not run on 5.1).
- `RAILS_ENV=production bundle exec rake redmine:plugins:migrate`: no new migrations (still 001-008),
  nothing changes in the database; plugin settings are kept as they are.
- Re-create the cron entry for the renewal, with the Ruby of the new installation on PATH
  (`rake` alone is not on PATH with rbenv):
  `12 6 * * * cd /var/lib/redmine && RAILS_ENV=production bundle exec rake redmine:issue_recurring:renew_all >> log/cron-issue_recurring.log 2>&1`
  (`bin/rails redmine:issue_recurring:renew_all` works as well).
- If Redmine 7 webhooks are used: nothing to do, the task now waits for its webhook jobs.
- Relations lost to the reopen bug between 2025-10-31 and the upgrade: not restored, Jan accepted the
  loss (decision q1, 2026-10-07). From 1.8.0-geoxyz on, reopen renewals keep the issue's relations.
- The version shown in Administration > Plugins becomes `1.8.0-geoxyz` (decision q3).

## How to test

```sh
./.codex/redmine_clone.sh 7.0-stable-GEOxyz      # or 5.1-stable / 6.1-stable / 7.0-stable
./.codex/test_setup.sh                                 # RMP_DB=mariadb for MariaDB, RMP_PROVISION_DB=0 if a server runs
./.codex/test_plugin.sh                                # minitest + rspec of this plugin
```

```sh
./.codex/start_server.sh       # real Redmine (production mode) with this plugin, seeded users and projects
./.codex/e2e.sh                # browser: smoke over the plugin's pages, core issue flows, test/e2e/*.mjs
./.codex/openai_review.sh      # independent OpenAI review of the diff, only when OPENAI_API_KEY is set
```
Write one scenario per function in `test/e2e/<function>.mjs` (example at the top of
`.codex/e2e/lib.mjs`); screenshots and a table per scenario land in `docs/e2e/`. Users:
`admin`, `manager` (every permission), `reporter` (no plugin permissions), `outsider` (no
membership); password `Redmine7Test!`. Needs Node with Playwright and Chromium
(`npm install -g playwright && npx playwright install --with-deps chromium`).

On GitHub the same runs by hand only: Actions > "Redmine tests (manual)" > Run workflow (tick
"e2e" for the browser run; screenshots come back as an artifact).

The coordinator's harness (`plugin-check.sh` in the migration kit, kept outside this repo) adds a
browser smoke test of every page the plugin adds and runs all GEOxyz plugins together; the
results quoted in the analysis come from it.

## How the migration session works (same for every plugin)

1. **Start**: `git fetch && git checkout redmine70-migration && git pull`. Read this whole file,
   including the analysis report at the bottom. Do not reopen decisions recorded here.
2. **Baseline, before you change anything**:
   - the plugin's tests on Redmine 7.0-stable-GEOxyz with PostgreSQL (MariaDB no longer required, Jan 2026-10-07);
   - a real running Redmine with this plugin (`./.codex/start_server.sh`) and the browser run
     (`./.codex/e2e.sh`: smoke over every page the plugin adds, plus the core issue flows).
   Write the numbers here. Something already broken now is a finding, not your regression.
3. **Inventory of functions**: list every function of the plugin in this file, in a table
   "function | how a user reaches it | scenario | screenshot". Take them from the README,
   `init.rb` (permissions, menus, settings, project modules), routes, hooks and view
   overrides, macros, mail handling, API endpoints, rake tasks and cron jobs. This table is the
   coverage list for step 8; a function that is not in it will not be tested.
4. **GEOxyz changes**: go through the table above, one item at a time. Each kept or re-made change
   is its own commit with a test that proves it. Record the verdict in the table.
5. **Work list**: then the numbered list, in order. One concern per commit.
6. **Portability**: everything must run on Redmine's supported databases (PostgreSQL,
   MySQL/MariaDB; SQLite where the plugin already supports it). Migrations must be reversible and
   are run down and up on PostgreSQL. Jan, 2026-10-07: GEOxyz runs PostgreSQL 16 only; keep SQL
   portable where it costs nothing, a MariaDB-only problem is a note, not a blocker.
7. **Together**: run with the other GEOxyz plugins installed (the migration kit's harness, or
   `RMP_EXTRA_PLUGINS`). A failure that only appears in combination is a finding to record here.
8. **End to end, visually, every function**: on the real Redmine from `start_server.sh`
   (production mode, the way GEOxyz runs it), write one scenario per function in
   `test/e2e/<function>.mjs` with `.codex/e2e/lib.mjs` and run them with `./.codex/e2e.sh`.
   - Each function as the users that matter: `admin`, `manager` (every permission, the
     plugin's included), `reporter` (member without the plugin's permissions), `outsider`
     (no membership, private project must stay invisible).
   - The failure paths too: setting off, permission absent, empty state, invalid input, the
     value that used to raise. A refusal that is shown is evidence as much as a success.
   - One screenshot per function and per path, with a caption saying what it proves. Open
     every screenshot and look at it: a picture nobody looked at proves nothing. Commit them
     in `docs/e2e/` and list them in the inventory table.
   - Functions without a page (mail in and out, REST API, rake tasks, cron, webhooks): exercise
     them against the same running instance (mails land in `redmine/tmp/mails`, `t.mails()`
     reads them; API through `t.page.request`) and record command and result.
   - Before pictures where behaviour or layout changes: the branch GEOxyz runs today, on
     Redmine 5.1, same scenarios, `RMP_E2E_OUT=docs/e2e/before`.
   - MariaDB e2e runs are no longer required (Jan, 2026-10-07).
9. **Independent review**: first your own, adversarial: re-read the whole diff as if someone
   else wrote it and you are paid to reject it. Then, **when `OPENAI_API_KEY` is set in the
   session**, `./.codex/openai_review.sh`: it sends the diff of this branch to an OpenAI model
   and writes `docs/reviews/openai-<date>-<sha>.md`. Every finding gets a `Resolution:` line
   there (fixed in <commit>, with a test, or why not). Fix, re-run the tests and the e2e set,
   and run the review again until it has nothing new that you accept. Without the key: write
   "OpenAI review: skipped, no OPENAI_API_KEY" in the report; never send code anywhere else.
10. **After the upgrade**: anything the production upgrade must do for this plugin (data fixes,
    settings, cron, files, removed features) goes into the section "After the upgrade".
11. **Finish**: update "Status", the inventory and the work list in this file, push
    `redmine70-migration`, and report: what changed, test numbers on both databases, e2e
    numbers (scenarios, screenshots, problems), the review result, what is left, what needs Jan.

### Stop and ask Jan when
- a GEOxyz change would be lost or behave differently for users;
- a new gem, a new setting with user impact, or a schema change not required by Redmine 7 seems needed;
- the change would send data to an external service (the OpenAI review of the code diff is the
  one exception Jan approved, and only when the key is present);
- upstream and GEOxyz disagree on behaviour and both are defensible.

## Rules

- **Target**: Redmine 7.0-stable-GEOxyz (https://github.com/jcatrysse/redmine), Rails 8.1, Ruby 3.3+.
  Core sources for comparison: branches `5.1-stable`, `6.1-stable`, `7.0-stable`, `7.0-stable-GEOxyz`.
- **Evidence**: never report a test, lint, browser check or review as passed without having seen
  it. Quote the summary lines; list the screenshots. "Should work" is not a result, and a green
  test suite is not proof that a feature works in the browser.
- **Tests**: never skip, delete or weaken a test. A test that encodes Redmine 5 markup or
  behaviour is updated to Redmine 7, with the reason in the commit. Every fix gets a test that
  fails without it.
- **Minimal diffs** in the plugin's own style. No reformatting, no unrelated refactoring.
  Something wrong elsewhere: write it down here, do not fix it in passing.
- **Security**: authorization on every action and entry point; `safe_attributes`, never
  `to_unsafe_hash` into `update`; no SQL built from params; no secrets in logs; no `html_safe` on
  user input.
- **Webhooks (new in Redmine 7)**: core sends issue payloads (core `issues/show.api.rsb`, rendered
  as the webhook owner) to webhook endpoints, past plugin hooks and controller patches. If the
  plugin hides, adds or changes issue data, make webhooks consistent with that or record why not.
- **Redmine 7 conventions**: SVG icons through `sprite_icon` (the `icon icon-*` CSS is gone),
  Propshaft assets under `assets/` (`/assets/plugin_assets/<id>/...`), the new header and user menu,
  `ContextMenus::*Controller`, Loofah-based text formatting, Chart.js as an ES module, sudo mode
  (on by default: `t.sudo()` in a scenario). The breaker list is in the migration kit's CHECKLIST.md.
- **Locales**: keep the locales the plugin ships in sync; translate a new key by matching the
  closest existing key in the same file, not from scratch; do not add new languages.
- **No 5.1** (Jan, 2026-10-07): GEOxyz goes straight to Redmine 7; no backports, nothing cherry-picked
  to the default branch; no code paths that exist only for 5.1.
- **Patching core**: a core method that other plugins also patch is patched with `prepend`, never
  `alias_method` (Jan, 2026-10-07).
- **Git**: work on `redmine70-migration` only; never push to the default branch; never force-push
  a branch someone else uses. Descriptive commit messages (what and why). Push after every
  commit, together with the updated status in this file: a cloud session can stop at a usage
  limit, and work that is not pushed is lost with its container.
- **GitHub Actions**: manual only (`workflow_dispatch`). Do not add push, pull_request or schedule
  triggers.

## Definition of done

- All items of the work list are done or explicitly deferred with a reason, in this file.
- The plugin's tests are green on Redmine 7.0-stable-GEOxyz with PostgreSQL
  (numbers in this file); boot, production-like eager load, migrations up/down OK.
- Every function in the inventory exercised end to end on a real running Redmine, with and
  without permissions and on its failure paths; `./.codex/e2e.sh` green; screenshots looked at,
  committed in `docs/e2e/` and listed.
- Review done: your own, and the OpenAI review when the key is present, every finding resolved
  in `docs/reviews/`.
- No new failure when run together with the other GEOxyz plugins.
- "After the upgrade" lists every action production needs; "Status" is current.


## Analysis report (2026-10-06, Dutch)

# issue_recurring
- Gebruikte branch: master @ e6fae03 (2025-10-31) - plugin id issue_recurring, versie 1.7.2
- Upstream: cryptogopher/issue_recurring - upstream HEAD master @ 19d3997 (2024-08-11). Tracker van de auteur: it.michalczyk.pro/projects/issue-recurring (GitHub is de echte repo, geen mirror)
- Fork t.o.v. upstream: 3 eigen commits (9fd754a = cherry-pick van upstream-branch issue30 "additional_tags #5773", 241424b fix #6165, e6fae03 feature "copy issue relations"), 0 upstream-commits op master ontbreken
- Andere relevante branches: upstream `issue49` (0f6ea1e, 2025-03-09, 23 commits voorbij master): WIP voor 1.8 ("random_new WIP", nieuwe migratie 009 die `recurrence_of` naar issue relations verhuist, hernoemt associaties). Geen enkele R6/R7-compat-wijziging (zelfde `enum x:` en `fixture_path=`). `update_docs` (1 docs-commit), `issue30` (al gecherrypickt). Upstream-ticket #50 "Redmine 6.0.x compatibility" (2025-10-18) is onbeantwoord. Geen onderhouden fork gevonden.
- Baseline: 8 migraties (001-008), geen plugin-Gemfile-runtime-gems (dev/test: rails-controller-testing, byebug, ruby-prof), minitest (unit, integration, migration, system).

## 1. Werkt out of the box op Redmine 7?   NEE
Harness `issue_recurring@origin/master` (results/1006-085128-s5-issue_recurring_origin_master):
- OK bundle, boot, migraties dev+test
- FAIL eager load - `app/models/issue_recurrence.rb:7` `enum creation_mode: {...}`: keyword-vorm van `enum` bestaat niet meer in Rails 8 -> ArgumentError bij het laden van de klasse.
- FAIL 6x HTTP 500 (`/issues/1`, `/issues/2`, `/issues/1.pdf`, `/recurrences/1/edit`) - zelfde oorzaak, via `LoadIssueRecurrences#load_issue_recurrences` (concern op IssuesController#show): **elke issue-pagina geeft 500** zodra de plugin geinstalleerd is.
- FAIL minitest - `test/test_helper.rb:6` `self.fixture_path=` bestaat niet meer (Rails 7.2) -> NoMethodError, geen enkele test start.

## 2. Upstream sync?   UPSTREAM DOOD
Upstream master is ouder dan onze fork (laatste commit 2024-08-11, volledig in onze master). `issue49` is onafgewerkt WIP met een datamigratie en lost niets op voor R7; niet mergen. Ticket #50 (Redmine 6) staat een jaar zonder antwoord. Geen trial merge nodig (niets om te mergen).

## 3. Werkt na sync op Redmine 7?   n.v.t.

## 4. Complexiteit en blokkers   score 2
- Blokkers:
  - `app/models/issue_recurrence.rb:7,13,23,38` - `enum x: {...}` -> ArgumentError (Rails 8) - `enum :x, {...}` (gefixt in 59879c4)
  - `app/models/issue_recurrence.rb` (`#to_s`, `#log`) - `l()` bestaat niet meer op dit model: Redmine 6.0 (#38975) mengt `Redmine::I18n` (en alle acts_as_*) nu in `ApplicationRecord` i.p.v. `ActiveRecord::Base`; dit model erft van `ActiveRecord::Base` -> NoMethodError -> HTTP 500 op elke issue met een herhalingsschema en bij `renew_all` zodra er een waarschuwing gelogd wordt. Fix: `include Redmine::I18n` (no-op op 5.1) (gefixt in 59879c4). **Staat niet in CHECKLIST.md** - de harness-smoke zag het niet omdat de seed-issues geen schema hebben; gevonden via de plugin-tests (76 x 500).
  - `test/test_helper.rb:6`, `test/unit/issue_recurrence_test.rb:4`, `test/application_system_test_case.rb:31` - `fixture_path=` -> `fixture_paths=`, plus `fixture_table_names = []`: Redmine's `fixtures :all` wordt geerfd; Rails 6.1 laadde de ontbrekende core-tabellen stil als lege tabellen, Rails 7.1+ gooit "No fixture files found for attachments" (gefixt in 22fab85, alleen tests)
- Stille breuken:
  - `lib/issue_recurring/schema_patch.rb` + `schema_statements_patch.rb` (workaround voor core #37803, nog steeds open): de prepend gebeurt op `ActiveRecord::Schema`, maar Rails 7.1+ laadt schema.rb via `ActiveRecord::Schema[8.1]`, een aparte klasse -> patch wordt nooit uitgevoerd (gemeten: `Schema[8.1].ancestors` bevat de patch niet). `db:schema:load` / `db:test:prepare` herstelt de plugin-migratieversies dus niet meer, terwijl de dumper ze wel schrijft (`issue_recurring: 8`). En als hij wel liep: `ActiveRecord::SchemaMigration.create_table` bestaat niet meer (Rails 7.1). Gevolg nu: de 3 MigrationsTest-errors (Rails' `maintain_test_schema` laadt schema.rb in de test-DB, plugin-versies weg, test probeert 001 opnieuw -> PG::DuplicateTable). Alleen dev/test, geen productie-impact.
  - `lib/tasks/issue_recurring.rake:20-23` - dev-task `redmine:plugins:test:migration` roept `Rails::TestUnit::Runner.rake_run` aan, bestaat niet meer in Rails 8.1 (gemeten) -> NoMethodError als iemand die task start. Productie-task niet geraakt.
  - `lib/tasks/issue_recurring.rake:8` - `require_relative '../../../../config/environment'` bovenaan: elke `rake`-aanroep op de server (ook `db:migrate`, `assets:precompile`) boot de volledige app bij het laden van de rakefiles. Was op 5.1 ook zo; werkt op R7, maar maakt elke rake-run trager en breekt rake-taken die zonder DB moeten draaien.
  - Iconen: `lib/issue_recurring/issues_helper_patch.rb:99,104` `class: 'icon icon-edit'` / `'icon icon-del'` -> Edit/Delete in het herhalingspaneel zonder icoon (#43206, cosmetisch).
  - `issues_helper_patch.rb` `last_recurrence`/`next_recurrences` bouwen HTML met `.html_safe` op geinterpoleerde strings (bestaand, niet R7-specifiek).
- Cron-entrypoint (gemeten op R7 / Rails 8.1): `bundle exec rake redmine:issue_recurring:renew_all` en `bin/rails redmine:issue_recurring:renew_all` werken: schema "copy first, elke dag" op een issue met startdatum -3 dagen maakte 4 kopieen (#12-#15) met juiste datums, status New, `recurrence_of` gezet, count=4. `Mailer.with_synched_deliveries` bestaat nog in 7.0. Let op: in deze container staat `rake` niet in PATH (rbenv), cron moet `bundle exec rake` of `bin/rails` gebruiken met de juiste Ruby-PATH.
- Runtime na fix (gemeten): issue-pagina met schema 200 en toont "Copy issue every 1 day, based on start date ... Last: #15 ... Predicted: ...", `/recurrences/1/edit.js` 200, `/projects/geoxyz-verify/recurrences` 200, `/settings/plugin/issue_recurring` 200, geen 500 in development.log.
- Overlap met Redmine 7 core: geen (core heeft geen terugkerende issues).
- Open werk voor ansif:
  1. Schema-patches herschrijven voor Rails 7.1+: prepend op `ActiveRecord::Schema::Definition` (bestaat pas vanaf Rails 7.1, dus versie-guard voor 5.1) en `pool.schema_migration.create_table` i.p.v. `ActiveRecord::SchemaMigration.create_table`; daarna moeten de 3 MigrationsTest-tests groen worden. Alternatief: patches schrappen en tests altijd via `redmine:plugins:migrate` voorbereiden.
  2. `redmine:plugins:test:migration` aanpassen (`Rails::TestUnit::Runner.run_from_rake`) of schrappen.
  3. `require_relative '.../config/environment'` uit de rakefile halen (`=> :environment` volstaat al).
  4. Iconen naar `sprite_icon('edit'/'del', ...)` met fallback voor 5.1 (cosmetisch).
  5. Let op: de branch vereist nu Rails >= 7.0 voor `enum :x, {}` -> draait niet meer op Redmine 5.1 (Rails 6.1). Alleen deployen samen met de 7.0-upgrade.

## Branch redmine70-migration
- Basis: origin/master @ e6fae03 (geen upstream-merge)
- Commits:
  - 59879c4 Make IssueRecurrence load and render on Redmine 7 (Rails 8.1)
  - 22fab85 Load only the plugin's own fixtures in tests on Rails 7.1+
- Eindresultaat harness (herhaald met de bijgewerkte harness van 09:25 die alle projectmodules aanzet, results/1006-093221-s5-issue_recurring_redmine70-migration): OK bundle, boot, eager load, migraties dev+test, rollback; FAIL minitest 91 runs, 10632 assertions, 1 failure, 3 errors; OK smoke 70/70 (10 plugin routes, module issue_recurring aan; INFO 404 `/recurrences/1/edit` zonder bestaand record = normaal).
  - 3 errors: alle 3 MigrationsTest (schema-patch, zie stille breuken).
  - 1 failure `test/integration/issue_recurrences_test.rb:2783` (`test_renew_applies_journal_mode_configuration_setting`): flaky, niet R7. De vorige run (1006-091234, andere seed) had 0 failures. De test vergelijkt de volgorde van `Journal.last(2)`, maar `IssueRecurrence.renew_all` itereert over `select(:issue_id).distinct` zonder ORDER BY, dus PostgreSQL bepaalt de volgorde waarin de twee issues hun journal krijgen.
- Rollback migraties: OK

