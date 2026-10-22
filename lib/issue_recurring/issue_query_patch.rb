module IssueRecurring
  module IssueQueryPatch
    # Filter "Recurrence of": the issues of the series of a template.
    def initialize_available_filters
      super
      return unless IssueRecurrenceSeries.visible_in?(project)

      add_available_filter(
        'recurrence_of',
        type: :list_optional,
        name: l(:field_recurrence_of),
        values: lambda { IssueRecurrenceSeries.template_values(project) }
      )
    end
    protected :initialize_available_filters

    def sql_for_recurrence_of_field(field, operator, value)
      IssueRecurrenceSeries.sql_for_filter("#{Issue.table_name}.id", operator, value)
    end
  end
end
