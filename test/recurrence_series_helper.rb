# Builds recurrence series the way the plugin does: a schedule on a template
# and recurrences made by IssueRecurrence#create, the method renew_all calls.
module RecurrenceSeriesHelper
  def add_subtask(parent, **attributes)
    Issue.create!({
      project: parent.project, tracker: parent.tracker, author: parent.author,
      subject: "Subtask of ##{parent.id}", parent_issue_id: parent.id,
      start_date: parent.start_date, due_date: parent.due_date
    }.merge(attributes))
  end

  def schedule(template, **attributes)
    prev_user, User.current = User.current, users(:alice)
    recurrence = IssueRecurrence.new({
      creation_mode: :copy_first, anchor_mode: :first_issue_fixed, anchor_to_start: true,
      mode: :daily, multiplier: 1, include_subtasks: false
    }.merge(attributes))
    recurrence.issue = template
    recurrence.save!
    recurrence
  ensure
    User.current = prev_user
  end

  # Creates +count+ recurrences, a day apart, and returns them.
  def renew(recurrence, count = 1)
    Array.new(count) do
      date = recurrence.issue.start_date + (recurrence.count + 1).days
      recurrence.create(start: date, due: date)
      recurrence.reload.last_issue
    end
  end

  def log_time(issue, hours, user: users(:alice), spent_on: Date.current)
    TimeEntry.create!(
      project: issue.project, issue: issue, user: user, author: user, hours: hours,
      spent_on: spent_on, activity: enumerations(:time_entry_activity_01)
    )
  end

  # Template issue_01 with a subtask, a schedule including subtasks, two
  # recurrences (each with a subtask copy) and a subtask added by hand below the
  # first recurrence; issue_02 belongs to no series.
  def build_series
    @template = issues(:issue_01)
    @template.update!(start_date: Date.current - 30, due_date: Date.current - 30,
                      estimated_hours: 2)
    @subtask = add_subtask(@template, estimated_hours: 1)
    @recurrence = schedule(@template.reload, include_subtasks: true)
    @copy1, @copy2 = renew(@recurrence, 2)
    @subtask_copy1 = @copy1.children.first
    @subtask_copy2 = @copy2.children.first
    @manual = add_subtask(@copy1)
    @other = issues(:issue_02)
  end

  # Template issue_03 with one recurrence: 2 + 3 = 5 hours.
  def build_second_series
    @template2 = issues(:issue_03)
    @template2.update!(start_date: Date.current - 20, due_date: Date.current - 20,
                       estimated_hours: 1)
    @copy2_1, = renew(schedule(@template2))
    log_time(@template2, 2)
    log_time(@copy2_1, 3)
  end

  # 1 + 2 + 3 + 4 + 5 + 6 = 21 hours on the series, 7 on issue_02.
  def log_series_time
    [@template, @subtask, @copy1, @subtask_copy1, @manual, @copy2].each_with_index do |issue, i|
      log_time(issue, i + 1)
    end
    log_time(@other, 7)
  end
end
