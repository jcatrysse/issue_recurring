require_relative '../test_helper'

class SchemaTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  # No fixtures: Redmine's fixtures :all would stay behind without transactions
  self.fixture_table_names = []

  # db:schema:load and db:test:prepare load db/schema.rb, which records plugin
  # migration versions as define(..., issue_recurring: N). Loading it has to put
  # those versions back into schema_migrations (workaround for Redmine #37803).
  def test_schema_define_restores_plugin_migration_versions
    plugin = Redmine::Plugin.find('issue_recurring')
    expected = plugin.migrations.sort
    schema = ActiveRecord::Schema.respond_to?(:[]) ?
      ActiveRecord::Schema[ActiveRecord::Migration.current_version] : ActiveRecord::Schema

    delete_plugin_versions
    assert_equal [], plugin_versions

    ActiveRecord::Migration.suppress_messages do
      schema.define(issue_recurring: plugin.latest_migration) {}
    end
    assert_equal expected, plugin_versions
  ensure
    missing = expected - plugin_versions
    if missing.any?
      connection.execute("INSERT INTO schema_migrations (version) VALUES " +
        missing.map { |v| "(#{connection.quote("#{v}-issue_recurring")})" }.join(', '))
    end
    Redmine::Plugin::Migrator.instance_variable_get(:@all_versions)&.delete('issue_recurring')
  end

  private

  def connection
    ActiveRecord::Base.connection
  end

  def plugin_versions
    connection.select_values("SELECT version FROM schema_migrations")
      .grep(/-issue_recurring\z/).map(&:to_i).sort
  end

  def delete_plugin_versions
    connection.execute("DELETE FROM schema_migrations WHERE version LIKE '%-issue_recurring'")
    Redmine::Plugin::Migrator.instance_variable_get(:@all_versions)&.delete('issue_recurring')
  end
end
