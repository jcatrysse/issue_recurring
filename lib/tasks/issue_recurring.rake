desc <<-END_DESC
Create pending recurrences for issues.

Example:
  RAILS_ENV=production rake redmine:issue_recurring:renew_all 
END_DESC

namespace :redmine do
  namespace :issue_recurring do
    task :renew_all => :environment do
      Mailer.with_synched_deliveries { IssueRecurrence.renew_all }
    end
  end

  namespace :plugins do
    namespace :test do
      desc 'Runs the plugins migration tests.'
      task :migration => "db:test:prepare" do |t|
        $: << "test"
        test_files = FileList["plugins/#{ENV['NAME'] || '*'}/test/migration/**/*_test.rb"]
        # Rails >= 7.1 replaced rake_run with run_from_rake
        if Rails::TestUnit::Runner.respond_to?(:run_from_rake)
          Rails::TestUnit::Runner.run_from_rake 'test', test_files
        else
          Rails::TestUnit::Runner.rake_run test_files
        end
      end
    end
  end
end
