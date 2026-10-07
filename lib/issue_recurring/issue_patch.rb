module IssueRecurring
  module IssuePatch
    extend ActiveSupport::Concern

    included do
      include InstanceMethods

      has_many :recurrences, class_name: 'IssueRecurrence', dependent: :destroy

      belongs_to :recurrence_of, class_name: 'Issue', validate: true
      has_many :recurrence_copies, class_name: 'Issue', foreign_key: 'recurrence_of_id',
        dependent: :nullify

      after_destroy :substitute_if_last_issue
      before_validation :drop_recurrences_not_manageable, on: :create

      # Other plugins patch #copy_from too; prepend, as alias_method mixed with
      # their prepend recurses.
      prepend CopyFromWithRecurrences
    end

    module CopyFromWithRecurrences
      def copy_from(arg, options={})
        super

        unless options[:skip_recurrences]
          self.recurrence_of = nil

          if Setting.plugin_issue_recurring[:copy_recurrences]
            self.recurrences = @copied_from.recurrences.map(&:dup)
          end
        end

        self
      end
    end

    module InstanceMethods
      # Recurrences copied along (setting copy_recurrences) are created by the
      # user copying the issue; without the plugin's permissions in the target
      # project they would make the whole copy invalid. Copy the issue without them.
      def drop_recurrences_not_manageable
        return if recurrences.empty?
        return if User.current.allowed_to?(:view_issue_recurrences, project) &&
          User.current.allowed_to?(:manage_issue_recurrences, project)

        self.recurrences = []
      end

      def substitute_if_last_issue
        return if self.recurrence_of.blank?
        r = self.recurrence_of.recurrences.find_by(last_issue: self)
        return if r.nil?
        r.update!(last_issue: r.issue.recurrence_copies.last)
      end

      def default_reassign
        self.assigned_to = nil
        default_assign
      end
    end
  end
end
