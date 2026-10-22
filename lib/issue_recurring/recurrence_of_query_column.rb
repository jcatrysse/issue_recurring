module IssueRecurring
  # Column "Recurrence of" of the issue and time entry lists: the template of the
  # series the issue (of the time entry) belongs to. Sorted and grouped by the
  # same SQL as the filter; values are looked up once per issue and template.
  class RecurrenceOfQueryColumn < QueryColumn
    def initialize
      super(:recurrence_of, sortable: IssueRecurrenceSeries.template_sql, groupable: true,
                            caption: :field_recurrence_of)
      @template_ids = {}
      @templates = {}
    end

    def group_by_statement
      IssueRecurrenceSeries.template_sql
    end

    def value_object(object)
      issue = object.is_a?(Issue) ? object : object.issue
      # A time entry's issue is joined only when visible; the SQL then sees none
      return if issue.nil? || (!object.is_a?(Issue) && !issue.visible?)

      template(template_id(issue.id, issue.recurrence_of_id, issue.parent_id))
    end

    def value(object)
      value_object(object)
    end

    # Grouped queries count and total by template id; the groups are templates.
    def group_values(result)
      result.transform_keys { |id| template(id) }
    end

    private

    # Same rule as IssueRecurrenceSeries.template_sql: walks up the parents,
    # one small query per ancestor not seen yet in this list.
    def template_id(id, recurrence_of_id, parent_id)
      @template_ids.fetch(id) do
        @template_ids[id] = recurrence_of_id ||
          (id if all_template_ids.include?(id)) ||
          (parent_template_id(parent_id) if parent_id)
      end
    end

    def parent_template_id(parent_id)
      @template_ids.fetch(parent_id) do
        recurrence_of_id, grandparent_id = Issue.where(id: parent_id).pick(:recurrence_of_id, :parent_id)
        template_id(parent_id, recurrence_of_id, grandparent_id)
      end
    end

    def all_template_ids
      @all_template_ids ||=
        (IssueRecurrence.distinct.pluck(:issue_id) +
         Issue.where.not(recurrence_of_id: nil).distinct.pluck(:recurrence_of_id)).to_set
    end

    # The template, or "#id" when the user cannot see it (or it is gone), as
    # core shows an issue it cannot link to.
    def template(id)
      return if id.nil?

      @templates.fetch(id.to_i) do
        issue = Issue.find_by(id: id)
        @templates[id.to_i] = issue && issue.visible? ? issue : "##{id}"
      end
    end
  end
end
