require_relative '../test_helper'

class FixturesTest < ActiveSupport::TestCase
  self.fixture_paths = [File.expand_path('../../fixtures/', __FILE__)]
  self.fixture_table_names = []
  fixtures :users, :projects, :roles, :members, :member_roles, :enabled_modules

  # The plugin's users.yml replaces core's, so it has to carry the builtin
  # groups too: core User#roles reads them for users without a membership
  # (reached by other plugins' menu conditions, e.g. redmine_contacts).
  def test_roles_of_users_without_membership
    assert_nothing_raised do
      users(:admin).roles.to_a
      User.anonymous.roles.to_a
    end
  end

  # redmine_view_issue_description refuses issue pages (403) to roles without
  # its permission; the test roles that view issues have it when installed.
  def test_roles_viewing_issues_may_view_descriptions_when_that_plugin_is_installed
    installed = Redmine::Plugin.installed?(:redmine_view_issue_description)
    roles = Role.where(builtin: [0, 1, 2]).select { |role| role.has_permission?(:view_issues) }
    assert_equal 5, roles.size
    roles.each do |role|
      assert_equal installed, role.has_permission?(:view_issue_description), role.name
    end
  end
end
