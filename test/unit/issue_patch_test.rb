require_relative '../test_helper'

class IssuePatchTest < ActiveSupport::TestCase
  self.fixture_paths = [File.expand_path('../../fixtures/', __FILE__)]
  self.fixture_table_names = []
  fixtures :issues, :issue_statuses,
    :users, :email_addresses, :trackers, :projects,
    :roles, :members, :member_roles, :enabled_modules, :workflow_transitions,
    :custom_fields, :enumerations

  def setup
    @issue1 = issues(:issue_01)
    @issue1.update!(start_date: Date.new(2019, 4, 8), due_date: Date.new(2019, 4, 12))
    User.current = users(:alice)
    IssueRecurrence.create!(issue: @issue1, mode: :weekly, multiplier: 2)
    Setting.plugin_issue_recurring =
      Setting.plugin_issue_recurring.merge(copy_recurrences: true)
  end

  # Other plugins patch Issue#copy_from as well. Mixing alias_method with their
  # prepend recurses, so this plugin has to prepend too.
  def test_copy_from_is_patched_with_prepend
    owner = Issue.instance_method(:copy_from).owner
    assert_not_equal Issue, owner
    assert Issue.ancestors.index(owner) < Issue.ancestors.index(Issue)
    assert_not Issue.method_defined?(:copy_from_without_recurrences)
  end

  def test_copy_from_works_together_with_another_prepended_patch
    other_plugin = Module.new do
      def copy_from(arg, options = {})
        super
        @other_plugin_copied = true
        self
      end
    end
    issue_class = Class.new(Issue) do
      def self.name
        'Issue'
      end
      prepend other_plugin
    end

    copy = issue_class.new.copy_from(@issue1)
    assert copy.instance_variable_get(:@other_plugin_copied)
    assert_equal [['weekly', 2]], copy.recurrences.map { |r| [r.mode, r.multiplier] }
    assert_nil copy.recurrence_of
  end

  def test_copy_from_skips_recurrences_when_asked
    copy = Issue.new.copy_from(@issue1, skip_recurrences: true)
    assert_empty copy.recurrences
  end
end
