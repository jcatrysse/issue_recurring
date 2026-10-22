-- Spike of 2026-10-22 for docs/SPENT-TIME.md: synthetic Redmine-like data in PostgreSQL 16 and the
-- queries measured there. Run as: sudo -u postgres psql < spike.sql (it creates and drops only the database 'spike').
-- 1. Data set
DROP DATABASE IF EXISTS spike;
CREATE DATABASE spike;
\c spike
CREATE TABLE issues (id serial PRIMARY KEY, project_id int NOT NULL, parent_id int, root_id int, lft int, rgt int,
  recurrence_of_id int, estimated_hours float);
CREATE TABLE issue_recurrences (id serial PRIMARY KEY, issue_id int);
CREATE TABLE time_entries (id serial PRIMARY KEY, project_id int, issue_id int, user_id int, hours float,
  spent_on date, tyear int, tmonth int, tweek int);
DO $$
DECLARE t int; c int; n int; pid int; nid int; k int; proj int;
BEGIN
  FOR t IN 1..400 LOOP
    proj := (t % 20) + 1;
    INSERT INTO issues(project_id, estimated_hours) VALUES (proj, 4) RETURNING id INTO pid;
    IF t <= 40 THEN
      UPDATE issues SET root_id = pid, lft = 1, rgt = 8 WHERE id = pid;
      FOR k IN 1..3 LOOP
        INSERT INTO issues(project_id, parent_id, root_id, lft, rgt, estimated_hours) VALUES (proj, pid, pid, 2*k, 2*k+1, 1);
      END LOOP;
    ELSE
      UPDATE issues SET root_id = pid, lft = 1, rgt = 2 WHERE id = pid;
    END IF;
    INSERT INTO issue_recurrences(issue_id) VALUES (pid);
    n := 10 + (t * 37 % 290);
    FOR c IN 1..n LOOP
      INSERT INTO issues(project_id, recurrence_of_id, estimated_hours) VALUES (proj, pid, 4) RETURNING id INTO nid;
      IF t <= 40 THEN
        UPDATE issues SET root_id = nid, lft = 1, rgt = 8 WHERE id = nid;
        FOR k IN 1..3 LOOP
          INSERT INTO issues(project_id, parent_id, root_id, lft, rgt, recurrence_of_id, estimated_hours)
            VALUES (proj, nid, nid, 2*k, 2*k+1, pid, 1);
        END LOOP;
      ELSE
        UPDATE issues SET root_id = nid, lft = 1, rgt = 2 WHERE id = nid;
      END IF;
    END LOOP;
  END LOOP;
END $$;
INSERT INTO issues(project_id, estimated_hours) SELECT (g % 20) + 1, 2 FROM generate_series(1, 100000) g;
UPDATE issues SET root_id = id, lft = 1, rgt = 2 WHERE root_id IS NULL;
INSERT INTO time_entries(project_id, issue_id, user_id, hours, spent_on)
  SELECT 0, 1 + floor(random() * (SELECT max(id) FROM issues))::int, 1 + floor(random() * 200)::int,
         0.25 + round((random() * 7.75)::numeric, 2), DATE '2023-10-01' + floor(random() * 1096)::int
  FROM generate_series(1, 2000000);
UPDATE time_entries te SET project_id = i.project_id, tyear = extract(year FROM spent_on), tmonth = extract(month FROM spent_on),
  tweek = extract(week FROM spent_on) FROM issues i WHERE i.id = te.issue_id;
CREATE INDEX index_issues_on_root_id_and_lft_and_rgt ON issues (root_id, lft, rgt);
CREATE INDEX index_issues_on_recurrence_of_id ON issues (recurrence_of_id);
CREATE INDEX issues_project_id ON issues (project_id);
CREATE INDEX index_issues_on_parent_id ON issues (parent_id);
CREATE INDEX index_issue_recurrences_on_issue_id ON issue_recurrences (issue_id);
CREATE INDEX time_entries_issue_id ON time_entries (issue_id);
CREATE INDEX time_entries_project_id ON time_entries (project_id);
CREATE INDEX index_time_entries_on_user_id ON time_entries (user_id);
ANALYZE;
SELECT (SELECT count(*) FROM issues) issues, (SELECT count(*) FROM issues WHERE recurrence_of_id IS NOT NULL) copies,
  (SELECT count(*) FROM issue_recurrences) templates, (SELECT count(*) FROM time_entries) time_entries;

-- 2. Issue page: series totals for one template
\set T 23181
-- Q1 issue page: series spent time (template + copies + all their subtrees)
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY ON) SELECT SUM(te.hours), COUNT(*) FROM time_entries te
 WHERE te.issue_id IN (SELECT d.id FROM issues s JOIN issues d
   ON d.root_id = s.root_id AND d.lft >= s.lft AND d.rgt <= s.rgt
   WHERE s.id = :T OR s.recurrence_of_id = :T);
SELECT SUM(te.hours) hours, COUNT(*) entries FROM time_entries te
 WHERE te.issue_id IN (SELECT d.id FROM issues s JOIN issues d
   ON d.root_id = s.root_id AND d.lft >= s.lft AND d.rgt <= s.rgt
   WHERE s.id = :T OR s.recurrence_of_id = :T);
-- Q1b series estimated time
SELECT SUM(d.estimated_hours) estimated, COUNT(DISTINCT d.id) issues FROM issues d
 WHERE d.id IN (SELECT d2.id FROM issues s JOIN issues d2
   ON d2.root_id = s.root_id AND d2.lft >= s.lft AND d2.rgt <= s.rgt
   WHERE s.id = :T OR s.recurrence_of_id = :T);

-- 3. Module tab, stepwise: member ids first (index friendly), then time entries IN (ids)
WITH tpl AS (SELECT DISTINCT r.issue_id AS id FROM issue_recurrences r JOIN issues t ON t.id = r.issue_id WHERE t.project_id = 2),
 s AS (SELECT s.id, s.root_id, s.lft, s.rgt FROM issues s WHERE s.id IN (SELECT id FROM tpl)
       UNION ALL SELECT s.id, s.root_id, s.lft, s.rgt FROM issues s WHERE s.recurrence_of_id IN (SELECT id FROM tpl))
 SELECT DISTINCT d.id FROM s JOIN issues d ON d.root_id = s.root_id AND d.lft >= s.lft AND d.rgt <= s.rgt;
-- then: SELECT issue_id, SUM(hours) FROM time_entries WHERE issue_id IN (<ids>) GROUP BY issue_id;

-- 4. Report criterion and key equivalence
\timing on
-- baseline: core criterion "issue" over the same year
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY ON)
SELECT te.issue_id, te.tyear, te.tmonth, SUM(te.hours) FROM time_entries te LEFT JOIN issues i ON i.id = te.issue_id
WHERE te.spent_on BETWEEN DATE '2025-01-01' AND DATE '2025-12-31' GROUP BY 1, 2, 3;
-- hybrid key: own link first, ancestor lookup only for subtasks
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY ON)
SELECT CASE
  WHEN i.recurrence_of_id IS NOT NULL THEN i.recurrence_of_id
  WHEN EXISTS (SELECT 1 FROM issue_recurrences r WHERE r.issue_id = i.id)
    OR EXISTS (SELECT 1 FROM issues c WHERE c.recurrence_of_id = i.id) THEN i.id
  WHEN i.parent_id IS NOT NULL THEN
    (SELECT COALESCE(s.recurrence_of_id, s.id) FROM issues s
      WHERE s.root_id = i.root_id AND s.lft < i.lft AND s.rgt > i.rgt
        AND (s.recurrence_of_id IS NOT NULL
             OR EXISTS (SELECT 1 FROM issue_recurrences r WHERE r.issue_id = s.id)
             OR EXISTS (SELECT 1 FROM issues c WHERE c.recurrence_of_id = s.id))
      ORDER BY s.lft DESC LIMIT 1)
  END AS series, te.tyear, te.tmonth, SUM(te.hours)
FROM time_entries te LEFT JOIN issues i ON i.id = te.issue_id
WHERE te.spent_on BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
GROUP BY 1, 2, 3;
WITH full_key AS (
 SELECT (SELECT COALESCE(s.recurrence_of_id, s.id) FROM issues s
         WHERE s.root_id = i.root_id AND s.lft <= i.lft AND s.rgt >= i.rgt
           AND (s.recurrence_of_id IS NOT NULL OR EXISTS (SELECT 1 FROM issue_recurrences r WHERE r.issue_id = s.id)
                OR EXISTS (SELECT 1 FROM issues c WHERE c.recurrence_of_id = s.id))
         ORDER BY s.lft DESC LIMIT 1) AS series, SUM(te.hours) h
 FROM time_entries te JOIN issues i ON i.id = te.issue_id WHERE te.project_id = 3 GROUP BY 1),
hybrid AS (
 SELECT CASE WHEN i.recurrence_of_id IS NOT NULL THEN i.recurrence_of_id
  WHEN EXISTS (SELECT 1 FROM issue_recurrences r WHERE r.issue_id = i.id) OR EXISTS (SELECT 1 FROM issues c WHERE c.recurrence_of_id = i.id) THEN i.id
  WHEN i.parent_id IS NOT NULL THEN (SELECT COALESCE(s.recurrence_of_id, s.id) FROM issues s
      WHERE s.root_id = i.root_id AND s.lft < i.lft AND s.rgt > i.rgt
        AND (s.recurrence_of_id IS NOT NULL OR EXISTS (SELECT 1 FROM issue_recurrences r WHERE r.issue_id = s.id)
             OR EXISTS (SELECT 1 FROM issues c WHERE c.recurrence_of_id = s.id)) ORDER BY s.lft DESC LIMIT 1) END AS series,
  SUM(te.hours) h FROM time_entries te JOIN issues i ON i.id = te.issue_id WHERE te.project_id = 3 GROUP BY 1)
SELECT count(*) AS series_rows, count(*) FILTER (WHERE round(f.h::numeric, 2) IS DISTINCT FROM round(hy.h::numeric, 2)) AS mismatches
FROM full_key f FULL JOIN hybrid hy ON COALESCE(f.series, -1) = COALESCE(hy.series, -1);
-- and: the per-series filter total equals the report row for that series (template 23181 sits in project 2)
SELECT 'report row' src, SUM(te.hours) FROM time_entries te JOIN issues i ON i.id = te.issue_id
 WHERE (CASE WHEN i.recurrence_of_id IS NOT NULL THEN i.recurrence_of_id
  WHEN EXISTS (SELECT 1 FROM issue_recurrences r WHERE r.issue_id = i.id) OR EXISTS (SELECT 1 FROM issues c WHERE c.recurrence_of_id = i.id) THEN i.id
  WHEN i.parent_id IS NOT NULL THEN (SELECT COALESCE(s.recurrence_of_id, s.id) FROM issues s
      WHERE s.root_id = i.root_id AND s.lft < i.lft AND s.rgt > i.rgt
        AND (s.recurrence_of_id IS NOT NULL OR EXISTS (SELECT 1 FROM issue_recurrences r WHERE r.issue_id = s.id)
             OR EXISTS (SELECT 1 FROM issues c WHERE c.recurrence_of_id = s.id)) ORDER BY s.lft DESC LIMIT 1) END) = 23181
UNION ALL
SELECT 'filter', SUM(te.hours) FROM time_entries te WHERE te.issue_id IN (SELECT d.id FROM issues s JOIN issues d
   ON d.root_id = s.root_id AND d.lft >= s.lft AND d.rgt <= s.rgt WHERE s.id = 23181 OR s.recurrence_of_id = 23181);

-- 5. Filter 'any series' as per-row EXISTS
\timing on
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY ON)
SELECT SUM(te.hours), COUNT(*) FROM time_entries te JOIN issues i ON i.id = te.issue_id
WHERE te.project_id = 2 AND te.spent_on > DATE '2026-10-22' - 365
  AND (i.recurrence_of_id IS NOT NULL
       OR EXISTS (SELECT 1 FROM issue_recurrences r WHERE r.issue_id = i.id)
       OR EXISTS (SELECT 1 FROM issues c WHERE c.recurrence_of_id = i.id)
       OR (i.parent_id IS NOT NULL AND EXISTS (SELECT 1 FROM issues s
             WHERE s.root_id = i.root_id AND s.lft < i.lft AND s.rgt > i.rgt
               AND (s.recurrence_of_id IS NOT NULL
                    OR EXISTS (SELECT 1 FROM issue_recurrences r WHERE r.issue_id = s.id)
                    OR EXISTS (SELECT 1 FROM issues c WHERE c.recurrence_of_id = s.id)))));
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY ON)
SELECT SUM(te.hours), COUNT(*) FROM time_entries te JOIN issues i ON i.id = te.issue_id
WHERE te.spent_on > DATE '2026-10-22' - 365
  AND (i.recurrence_of_id IS NOT NULL
       OR EXISTS (SELECT 1 FROM issue_recurrences r WHERE r.issue_id = i.id)
       OR EXISTS (SELECT 1 FROM issues c WHERE c.recurrence_of_id = i.id)
       OR (i.parent_id IS NOT NULL AND EXISTS (SELECT 1 FROM issues s
             WHERE s.root_id = i.root_id AND s.lft < i.lft AND s.rgt > i.rgt
               AND (s.recurrence_of_id IS NOT NULL
                    OR EXISTS (SELECT 1 FROM issue_recurrences r WHERE r.issue_id = s.id)
                    OR EXISTS (SELECT 1 FROM issues c WHERE c.recurrence_of_id = s.id)))));
