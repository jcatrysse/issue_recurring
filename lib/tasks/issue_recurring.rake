desc <<-END_DESC
Create pending recurrences for issues.

Example:
  RAILS_ENV=production rake redmine:issue_recurring:renew_all 
END_DESC

namespace :redmine do
  namespace :issue_recurring do
    task :renew_all => :environment do
      Mailer.with_synched_deliveries { IssueRecurrence.renew_all }

      # Redmine >= 7 queues webhooks of created/reopened issues as jobs. The
      # :async adapter runs them inside this process: wait, or the last ones
      # are lost when rake exits.
      adapter = ActiveJob::Base.queue_adapter
      adapter.shutdown(wait: true) if adapter.is_a?(ActiveJob::QueueAdapters::AsyncAdapter)
    end
  end

  namespace :plugins do
    namespace :test do
      desc 'Runs the plugins migration tests.'
      task :migration => "db:test:prepare" do |t|
        $: << "test"
        test_files = FileList["plugins/#{ENV['NAME'] || '*'}/test/migration/**/*_test.rb"]
        Rails::TestUnit::Runner.run_from_rake 'test', test_files
      end
    end
  end
end
