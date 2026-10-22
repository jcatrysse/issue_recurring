require_relative '../test_helper'
require_relative '../recurrence_series_helper'

class IssueRecurrenceSeriesTest < ActiveSupport::TestCase
  self.fixture_paths = [File.expand_path('../../fixtures/', __FILE__)]
  self.fixture_table_names = []
  fixtures :issues, :issue_statuses,
    :users, :email_addresses, :trackers, :projects,
    :roles, :members, :member_roles, :enabled_modules, :workflow_transitions,
    :custom_fields, :enumerations

  include RecurrenceSeriesHelper

  def setup
    User.current = users(:alice)
    build_series
  end

  def teardown
    User.current = nil
  end

  def template_ids(*issues)
    Issue.where(id: issues.map(&:id))
      .pluck(:id, Arel.sql(IssueRecurrenceSeries.template_sql)).to_h
  end

  def test_recurrences_made_by_renewal_point_to_the_template
    [@copy1, @copy2, @subtask_copy1, @subtask_copy2].each do |issue|
      assert_equal @template, issue.recurrence_of, "##{issue.id}"
    end
    assert_equal @copy1, @subtask_copy1.parent
    assert_nil @subtask.recurrence_of
    assert_nil @manual.recurrence_of
  end

  def test_template_sql_assigns_every_issue_to_its_series
    members = [@template, @subtask, @copy1, @subtask_copy1, @manual, @copy2, @subtask_copy2]
    ids = template_ids(*members, @other)
    members.each { |issue| assert_equal @template.id, ids[issue.id], "##{issue.id}" }
    assert_nil ids[@other.id]
  end

  def test_template_without_schedules_keeps_its_series
    @recurrence.destroy!
    ids = template_ids(@template, @copy2, @manual)
    assert_equal [@template.id] * 3, ids.values_at(@template.id, @copy2.id, @manual.id)
  end

  def test_reopened_template_belongs_to_its_own_series
    issue = issues(:issue_03)
    issue.update!(start_date: Date.current - 5, due_date: Date.current - 5)
    recurrence = schedule(issue, creation_mode: :reopen, anchor_mode: :last_issue_flexible)
    renew(recurrence)
    assert_equal issue.id, issue.reload.recurrence_of_id
    assert_equal({issue.id => issue.id}, template_ids(issue))

    series = IssueRecurrenceSeries.for_templates([issue])[issue.id]
    assert_equal 1, series.issues_count
  end

  def test_series_below_a_recurrence_is_its_own
    inner = add_subtask(@copy1)
    inner_copy, = renew(schedule(inner))
    assert_equal @copy1, inner_copy.parent

    ids = template_ids(inner, inner_copy)
    assert_equal [inner.id, inner.id], ids.values_at(inner.id, inner_copy.id)
    ids_by_template = IssueRecurrenceSeries.issue_ids_by_template([@template.id, inner.id])
    assert_equal [inner.id, inner_copy.id].sort, ids_by_template[inner.id].sort
    assert_not_includes ids_by_template[@template.id], inner.id
    assert_not_includes ids_by_template[@template.id], inner_copy.id
  end

  def test_issue_ids_by_template
    expected = [@template, @subtask, @copy1, @subtask_copy1, @manual, @copy2, @subtask_copy2]
    ids = IssueRecurrenceSeries.issue_ids_by_template([@template.id, @other.id])
    assert_equal [@template.id], ids.keys
    assert_equal expected.map(&:id).sort, ids[@template.id].sort
  end

  def test_for_templates_totals
    log_series_time
    series = IssueRecurrenceSeries.for_templates([@template])[@template.id]
    assert_equal 21.0, series.spent_hours
    assert_equal 9.0, series.estimated_hours
    assert_equal 3, series.issues_count
    assert series.single_project?
  end

  def test_for_issue_from_any_issue_of_the_series
    [@template, @copy2, @manual].each do |issue|
      assert_equal @template, IssueRecurrenceSeries.for_issue(issue).template
    end
    assert_nil IssueRecurrenceSeries.for_issue(@other)
  end

  def test_spent_hours_of_time_entries_the_user_can_see
    roles(:developer).update!(time_entries_visibility: 'own')
    log_time(@copy1, 1, user: users(:alice))
    log_time(@copy2, 2, user: users(:bob))

    # Fresh users: the fixture instances keep the roles they loaded before the update
    User.current = User.find(users(:alice).id)
    assert_equal 1.0, IssueRecurrenceSeries.for_issue(@copy1).spent_hours
    User.current = User.find(users(:bob).id)
    assert_equal 2.0, IssueRecurrenceSeries.for_issue(@copy1).spent_hours
  end

  def test_query_column_values_follow_template_sql
    inner = add_subtask(@copy1)
    inner_copy, = renew(schedule(inner))
    issues = [@template, @subtask, @copy1, @subtask_copy1, @manual, @copy2, @subtask_copy2,
              inner, inner_copy, @other]
    ids = template_ids(*issues)
    column = IssueRecurring::RecurrenceOfQueryColumn.new
    issues.each do |issue|
      assert_equal ids[issue.id], column.value(Issue.find(issue.id))&.id, "##{issue.id}"
    end
    assert_equal @template, column.value(TimeEntry.new(issue: @manual))
    assert_nil column.value(TimeEntry.new)
  end

  def test_estimated_hours_nil_without_estimates
    Issue.where(id: IssueRecurrenceSeries.issue_ids_by_template([@template.id]).values.flatten)
      .update_all(estimated_hours: nil)
    assert_nil IssueRecurrenceSeries.for_issue(@template).estimated_hours
  end
end
