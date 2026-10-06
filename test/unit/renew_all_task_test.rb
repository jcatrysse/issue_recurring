require_relative '../test_helper'
require 'rake'

class RenewAllTaskTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class SlowJob < ActiveJob::Base
    def perform
      sleep 0.5
      RenewAllTaskTest.done = true
    end
  end

  class << self
    attr_accessor :done
  end

  def setup
    @rake = Rake::Application.new
    Rake.application = @rake
    Rake::Task.define_task(:environment)
    load File.expand_path('../../../lib/tasks/issue_recurring.rake', __FILE__)
    @adapter = ActiveJob::Base.queue_adapter
    self.class.done = false
  end

  def teardown
    ActiveJob::Base.queue_adapter = @adapter
    Rake.application = Rake::Application.new
  end

  # Webhooks of the issues created by the cron task are queued as jobs. With
  # the :async adapter (the Rails default) they run in the rake process, so
  # the task has to wait for them, or the last ones are lost when it exits.
  def test_renew_all_waits_for_jobs_queued_in_process
    ActiveJob::Base.queue_adapter = ActiveJob::QueueAdapters::AsyncAdapter.new
    renew_all = IssueRecurrence.method(:renew_all)
    IssueRecurrence.define_singleton_method(:renew_all) { |*| SlowJob.perform_later }
    @rake['redmine:issue_recurring:renew_all'].invoke
    assert self.class.done
  ensure
    IssueRecurrence.define_singleton_method(:renew_all, renew_all)
  end
end
