module IssueRecurring
  module TimeReportPatch
    private

    # Criterion "Recurrence of": one row per series, the template as its label.
    def load_available_criteria
      super
      if IssueRecurrenceSeries.visible_in?(@project)
        @available_criteria['recurrence_of'] = {
          sql: IssueRecurrenceSeries.template_sql,
          klass: Issue,
          label: :field_recurrence_of
        }
      end
      @available_criteria
    end
  end
end
