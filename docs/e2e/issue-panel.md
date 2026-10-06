# issue-panel

Run 2026-10-06T20:42:51.484Z against http://127.0.0.1:3000.

| screenshot | user | URL | shows |
|---|---|---|---|
| ![](issue-panel-manager-empty.png) | manager | `/issues/7` | Manager (view + manage): panel with Add link, no recurrence yet (empty state) |
| ![](issue-panel-admin.png) | admin | `/issues/7` | Admin: panel with Add link |
| ![](issue-panel-reporter-hidden.png) | reporter | `/issues/7` | Reporter (no plugin permission): the issue shows, the panel does not |
| ![](issue-panel-outsider-private.png) | outsider | `/issues/12` | Outsider: an issue of the private project is refused (403) |
| ![](issue-panel-module-off.png) | manager | `/issues/12` | Module "Issue recurring" disabled in the project: no panel for the manager |
| ![](issue-panel-module-on.png) | manager | `/issues/12` | Module enabled again: the panel is back |
