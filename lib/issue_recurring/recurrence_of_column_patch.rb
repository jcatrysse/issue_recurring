module IssueRecurring
  # Adds the column "Recurrence of" to IssueQuery and TimeEntryQuery.
  module RecurrenceOfColumnPatch
    def available_columns
      columns = super
      if IssueRecurrenceSeries.visible_in?(project) &&
          columns.none? { |c| c.is_a?(RecurrenceOfQueryColumn) }
        columns << RecurrenceOfQueryColumn.new
      end
      columns
    end

    private

    def grouped_query(&block)
      result = super
      column = group_by_column
      result && column.is_a?(RecurrenceOfQueryColumn) ? column.group_values(result) : result
    end
  end
end
