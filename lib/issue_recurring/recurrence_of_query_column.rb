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
      template(template_id(issue)) if issue
    end

    def value(object)
      value_object(object)
    end

    # Grouped queries count and total by template id; the groups are templates.
    def group_values(result)
      result.transform_keys { |id| template(id) }
    end

    private

    def template_id(issue)
      @template_ids.fetch(issue.id) do
        @template_ids[issue.id] = issue.recurrence_of_id ||
          (issue.id if all_template_ids.include?(issue.id)) ||
          ancestor_template_id(issue)
      end
    end

    def ancestor_template_id(issue)
      return if issue.parent_id.nil?

      issue.ancestors.reorder(lft: :desc).pluck(:id, :recurrence_of_id).each do |id, recurrence_of_id|
        return recurrence_of_id || id if recurrence_of_id || all_template_ids.include?(id)
      end
      nil
    end

    def all_template_ids
      @all_template_ids ||=
        (IssueRecurrence.distinct.pluck(:issue_id) +
         Issue.where.not(recurrence_of_id: nil).distinct.pluck(:recurrence_of_id)).to_set
    end

    def template(id)
      @templates[id.to_i] ||= Issue.find_by(id: id) if id
    end
  end
end
