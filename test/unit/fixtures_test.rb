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
end
