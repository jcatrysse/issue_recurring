# renew

Run 2026-10-07T16:31:48.577Z against http://127.0.0.1:3000.

| screenshot | user | URL | shows |
|---|---|---|---|
| ![](renew-before.png) | manager | `/issues/9` | Before the cron run: daily copy recurrence, "Last: -", next dates up to tomorrow |
| ![](renew-reopen-before.png) | manager | `/issues/10` | Before the cron run: the reopen-mode issue is closed and relates to "Recurring related issue" |
| ![](renew-after.png) | manager | `/issues/9` | After rake renew_all: 4 copies [[19,"2026-10-05","2026-10-06","New"],[20,"2026-10-06","2026-10-07","New"],[21,"2026-10-07","2026-10-08","New"],[22,"2026-10-08","2026-10-09","New"]]; "Last: #22" links the newest |
| ![](renew-copy.png) | manager | `/issues/22` | A copy: status New, its own dates, "This is a recurrence of #...", the "relates" relation copied (setting) |
| ![](renew-reopened.png) | manager | `/issues/10` | Reopen mode: the issue is open again with dates 2026-10-12 - 2026-10-14, its relation kept, a journal entry (journal mode "on reopen") |
| ![](renew-evidence.png) | manager | `/issues/22` | Mails: 4 "Recurring copy issue" messages to reporter (mail_notification all); webhooks received: issue.created for [19,20,21,22,23,24,25], issue.updated for the reopened #10: true |
