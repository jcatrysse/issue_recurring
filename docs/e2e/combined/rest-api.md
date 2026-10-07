# rest-api

Run 2026-10-07T17:03:47.054Z against http://127.0.0.1:3003.

| screenshot | user | URL | shows |
|---|---|---|---|
| ![](rest-api-issue-json.png) | manager | `/issues/7.json` | REST API with a recurrence on the issue: issue.json 200 (keys: id, project, tracker, status, priority, author, subject, description, start_date, due_date, done_ratio, is_private, estimated_hours, total_estimated_hours, impact_id, urgency_id, itil_priority_linked, spent_hours, total_spent_hours, created_on, updated_on, closed_on, relations); issues.json 200; issue.xml 200; recurrences.json 403 |

## Problems

- /issues/7.json as manager: HTTP 403, expected 200
