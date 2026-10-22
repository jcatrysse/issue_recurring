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
    protected :initialize_available_filters

    def sql_for_issue_recurrence_of_field(field, operator, value)
      IssueRecurrenceSeries.sql_for_filter("#{TimeEntry.table_name}.issue_id", operator, value)
    end
  end
end
