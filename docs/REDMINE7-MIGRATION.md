# Redmine 7 migration: issue_recurring

Start a Claude Code (or Codex) session on this repository, branch `redmine70-migration`, with:

> Read CLAUDE.md and docs/REDMINE7-MIGRATION.md, then carry out the Redmine 7 migration of this
> plugin as described there, on branch redmine70-migration. Report to me in Dutch at the end.

This file is the plan and the memory of that work. Update it as you go: verdicts, results,
what is left. Written 2026-10-06 from a measured analysis (report at the bottom).

## Status

| | |
|---|---|
| Plugin id | `issue_recurring` |
| GEOxyz runs today | `master` |
| Upstream | cryptogopher/issue_recurring (master 19d3997, 2024-08-11; inactive, R6 ticket #50 unanswered) |
| Runs on Redmine 7 as is | NEE |
| Upstream sync | UPSTREAM DOOD |
| After sync | n.v.t. |
| Complexity (1 trivial .. 5 rewrite) | 2 |
| Measured on | Redmine 7.0.1 (7.0-stable-GEOxyz + latest 7.0-stable), Rails 8.1.3.1, Ruby 3.3.6, PostgreSQL 16 and MariaDB 10.11 |
| Branch head when this file was written | `22fab85` |

## Already on this branch

- `59879c4` Make IssueRecurrence load and render on Redmine 7 (Rails 8.1)
- `22fab85` Load only the plugin's own fixtures in tests on Rails 7.1+

## Work list for the migration session

In this order: things that break, security, the GEOxyz changes, the open items, then the checks.

**Open items from the analysis** (Dutch; where they repeat a priority item, the priority item wins)

1. Rewrite schema_patch/schema_statements_patch for Rails 7.1+ (prepend ActiveRecord::Schema::Definition, pool.schema_migration) - fixes 3 MigrationsTest errors and db:schema:load plugin versions (dev/test only)
2. Fix or drop dev task redmine:plugins:test:migration (Rails::TestUnit::Runner.rake_run removed)
3. Drop require_relative config/environment from lib/tasks/issue_recurring.rake
4. Icons icon-edit/icon-del -> sprite_icon (cosmetic)
5. Branch needs Rails >= 7.0 (enum :x form): deploy only with the 7.0 upgrade

**Checks**

6. Run the plugin's whole test suite on Redmine 7.0-stable-GEOxyz with PostgreSQL AND MariaDB, and once on 5.1-stable if the branch is meant to stay 5.1-compatible.
7. Check Redmine 7 webhooks against this plugin (see "Rules"), and note the result here even if nothing is needed.
8. Verify every feature of the plugin by hand on a running Redmine 7 (screenshots).

## GEOxyz changes to review or re-apply

These GEOxyz commits are on the branch GEOxyz runs today and therefore on this branch. Review each one against the code it now sits on (upstream merges and Redmine 7 core): drop it if upstream or core now does the same, rewrite it if it is not up to the quality rules below (tests, I18n, security, portability), keep it otherwise. Record the verdict per commit in this file.

| commit | date | subject |
|---|---|---|
| `e6fae03` | 2025-10-31 | Feature: add an option to copy issue relations in recurrence |
| `241424b` | 2025-06-18 | Defect: issue_recuurent throws an error on the Custom Fields page #6165 |

## After the upgrade (production)

Actions the person doing the upgrade must take, or know about, for this plugin:

- Re-create the cron entry for `rake redmine:issue_recurring:renew_all`.

## How to test

```sh
./.codex/redmine_clone.sh 7.0-stable-GEOxyz      # or 5.1-stable / 6.1-stable / 7.0-stable
./.codex/test_setup.sh                                 # RMP_DB=mariadb for MariaDB, RMP_PROVISION_DB=0 if a server runs
./.codex/test_plugin.sh                                # minitest + rspec of this plugin
```
On GitHub the same runs by hand only: Actions > "Redmine tests (manual)" > Run workflow.

The coordinator's harness (`plugin-check.sh` in the migration kit, kept outside this repo) adds a
browser smoke test of every page the plugin adds and runs all GEOxyz plugins together; the
results quoted in the analysis come from it.

## How the migration session works (same for every plugin)

1. **Start**: `git fetch && git checkout redmine70-migration && git pull`. Read this whole file,
   including the analysis report at the bottom. Do not reopen decisions recorded here.
2. **Baseline**: set up Redmine 7.0-stable-GEOxyz and run the plugin's tests on PostgreSQL and
   on MariaDB (see "How to test"). Write the numbers here before you change anything.
3. **GEOxyz changes**: go through the table above, one item at a time. Each kept or re-made change
   is its own commit with a test that proves it. Record the verdict in the table.
4. **Work list**: then the numbered list, in order. One concern per commit.
5. **Portability**: everything must run on Redmine's supported databases (PostgreSQL,
   MySQL/MariaDB; SQLite where the plugin already supports it). Migrations must be reversible and
   are run down and up on PostgreSQL and MariaDB.
6. **Browser**: start a Redmine 7 with this plugin, exercise every feature as admin and as a
   normal user with and without the plugin's permissions, and save screenshots (before on 5.1 or
   the old branch, after on 7.0) where behaviour or layout matters.
7. **Together**: run with the other GEOxyz plugins installed (the migration kit's harness, or
   `RMP_EXTRA_PLUGINS`). A failure that only appears in combination is a finding to record here.
8. **After the upgrade**: anything the production upgrade must do for this plugin (data fixes,
   settings, cron, files, removed features) goes into the section "After the upgrade".
9. **Finish**: update "Status" and the work list in this file, push `redmine70-migration`, and
   report: what changed, test numbers on both databases, what is left, what needs Jan.

### Stop and ask Jan when
- a GEOxyz change would be lost or behave differently for users;
- a new gem, a new setting with user impact, or a schema change not required by Redmine 7 seems needed;
- the change would send data to an external service;
- upstream and GEOxyz disagree on behaviour and both are defensible.

## Rules

- **Target**: Redmine 7.0-stable-GEOxyz (https://github.com/jcatrysse/redmine), Rails 8.1, Ruby 3.3+.
  Core sources for comparison: branches `5.1-stable`, `6.1-stable`, `7.0-stable`, `7.0-stable-GEOxyz`.
- **Evidence**: never report a test, lint or browser check as passed without having seen it.
  Quote the summary lines. "Should work" is not a result.
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
  `ContextMenus::*Controller`, Loofah-based text formatting, Chart.js as an ES module.
  The breaker list is in the migration kit's CHECKLIST.md.
- **Locales**: keep the locales the plugin ships in sync; translate a new key by matching the
  closest existing key in the same file, not from scratch; do not add new languages.
- **5.1 compatibility**: prefer fixes that also run on Redmine 5.1 so they can be merged early;
  say so when a fix cannot.
- **Git**: work on `redmine70-migration` only; never push to the default branch; never force-push
  a branch someone else uses. Descriptive commit messages (what and why).
- **GitHub Actions**: manual only (`workflow_dispatch`). Do not add push, pull_request or schedule
  triggers.

## Definition of done

- All items of the work list are done or explicitly deferred with a reason, in this file.
- The plugin's tests are green on Redmine 7.0-stable-GEOxyz with PostgreSQL and MariaDB
  (numbers in this file); boot, production-like eager load, migrations up/down OK.
- Every feature verified by hand on Redmine 7; screenshots listed.
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

