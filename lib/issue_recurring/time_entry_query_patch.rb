module IssueRecurring
  module TimeEntryQueryPatch
    # Filter "Issue's Recurrence of": time spent on the series of a template.
    def initialize_available_filters
      super
      return unless IssueRecurrenceSeries.visible_in?(project)

      add_available_filter(
        'issue.recurrence_of',
        type: :list_optional,
        name: l(:label_attribute_of_issue, name: l(:field_recurrence_of)),
        values: lambda { IssueRecurrenceSeries.template_values(project) }
      )
    end

    # On the joined issue, which is the visible one only, like core's filters on
    # issue attributes; computed once per query, which builds its SQL many times.
    def sql_for_issue_recurrence_of_field(field, operator, value)
      (@recurrence_of_sql ||= {})[[operator, value]] ||=
        IssueRecurrenceSeries.sql_for_filter("#{Issue.table_name}.id", operator, value)
    end
  end
end
