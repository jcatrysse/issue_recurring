# Plugin data for the end-to-end scenarios, run by .codex/start_server.sh after
# the generic seed (and again by the scenarios through e2e_reset). Resets the
# issues below to a known state on every run: dates relative to today, status,
# no recurrences, plugin settings at their defaults.
User.current = User.find_by(login: 'admin')
project = Project.find_by!(identifier: 'e2e-project')
private_project = Project.find_by!(identifier: 'e2e-private')
tracker = project.trackers.first
today = Date.current

def reset_issue(project, tracker, subject, attrs)
  # copies made by renewals have the same subject: the original is the oldest
  issue = Issue.where(project_id: project.id, subject: subject).order(:id).first ||
          Issue.new(project: project, tracker: tracker, subject: subject,
                    author: User.find_by(login: 'manager'),
                    priority: IssuePriority.default || IssuePriority.first)
  issue.recurrences.destroy_all if issue.persisted?
  issue.status = tracker.default_status
  attrs.each { |k, v| issue.send("#{k}=", v) }
  issue.save!
  issue.reload
end

panel = reset_issue(project, tracker, 'Recurring panel issue',
                    start_date: today, due_date: today + 4)
reset_issue(project, tracker, 'Recurring undated issue', start_date: nil, due_date: nil)
copy = reset_issue(project, tracker, 'Recurring copy issue',
                   start_date: today - 3, due_date: today - 2,
                   assigned_to: User.find_by(login: 'manager'))
reopen = reset_issue(project, tracker, 'Recurring reopen issue',
                     start_date: today - 10, due_date: today - 8)
related = reset_issue(project, tracker, 'Recurring related issue', start_date: nil, due_date: nil)
reset_issue(private_project, private_project.trackers.first, 'Recurring private issue',
            start_date: today, due_date: today + 1)

[copy, reopen].each do |issue|
  IssueRelation.where(issue_from_id: [issue.id, related.id], issue_to_id: [issue.id, related.id]).delete_all
  IssueRelation.create!(issue_from: issue, issue_to: related, relation_type: 'relates')
end
closed = IssueStatus.where(is_closed: true).first
reopen.status = closed
reopen.save!

# Copies made by earlier runs keep pointing at the reset issues; detach them.
Issue.where(recurrence_of_id: [panel.id, copy.id, reopen.id]).update_all(recurrence_of_id: nil)

Setting.plugin_issue_recurring = Setting.available_settings['plugin_issue_recurring']['default']
private_project.enable_module!(:issue_recurring)

ids = {panel: panel.id, copy: copy.id, reopen: reopen.id, related: related.id,
       undated: Issue.where(subject: 'Recurring undated issue').order(:id).first.id,
       private: Issue.where(subject: 'Recurring private issue').order(:id).first.id}
puts "E2E_IDS #{ids.to_json}"
