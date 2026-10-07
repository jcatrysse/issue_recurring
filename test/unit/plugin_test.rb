require_relative '../test_helper'

class PluginTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # Jan, 2026-10-07: the Redmine 7 version is GEOxyz's own
  def test_version
    assert_equal '1.8.0-geoxyz', Redmine::Plugin.find(:issue_recurring).version
  end
end
