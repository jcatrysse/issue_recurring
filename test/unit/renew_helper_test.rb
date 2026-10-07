require_relative '../test_helper'

class RenewHelperTest < ActiveSupport::TestCase
  include IssueRecurringTestCase

  self.fixture_paths = [File.expand_path('../../fixtures/', __FILE__)]
  self.fixture_table_names = []
  fixtures :issues, :issue_statuses,
    :users, :email_addresses, :trackers, :projects,
    :roles, :members, :member_roles, :enabled_modules, :workflow_transitions,
    :custom_fields, :enumerations

  # test_renew_anchor_mode_fixed_one_issue_date_not_set fails now and then with
  # only "Last issue is invalid" (Jan, 2026-10-07, issue_recurring-q4: collect
  # more information the next time). The renew_all helper names the reason.
  def test_renew_all_reports_why_the_last_issue_is_invalid
    User.current = users(:alice)
    last_issue = issues(:issue_02)
    last_issue.subject = ''
    recurrence = IssueRecurrence.new(issue: issues(:issue_01))
    recurrence.last_issue = last_issue
    recurrence.errors.add(:last_issue, :invalid)

    original = IssueRecurrence.method(:renew_all)
    IssueRecurrence.define_singleton_method(:renew_all) do |*|
      raise ActiveRecord::RecordInvalid.new(recurrence)
    end
    # assert_difference reports exceptions as Minitest::UnexpectedError
    unexpected = assert_raises(Minitest::UnexpectedError) { renew_all(0) }
    e = unexpected.error
    assert_kind_of ActiveRecord::RecordInvalid, e
    assert_match(/Last issue is invalid/, e.message)
    assert_match(/Issue ##{last_issue.id}: Subject cannot be blank/, e.message)
    assert_same recurrence, e.record

    # and one level further: the issue the last issue is a recurrence of
    last_issue.subject = 'valid again'
    first_issue = issues(:issue_03)
    first_issue.subject = ''
    last_issue.recurrence_of = first_issue
    last_issue.errors.clear
    last_issue.errors.add(:recurrence_of, :invalid)
    e = assert_raises(Minitest::UnexpectedError) { renew_all(0) }.error
    assert_match(/Recurrence of is invalid; Issue ##{first_issue.id}: Subject cannot be blank/, e.message)
  ensure
    IssueRecurrence.define_singleton_method(:renew_all, original) if original
  end
end
