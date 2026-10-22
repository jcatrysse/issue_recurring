module IssueRecurrencesHelper
  def issue_link(r)
    link_to "##{r.issue.id}: #{r.issue.subject}", issue_path(r.issue)
  end

  def mode(r)
    s = 'issues.recurrences.form.mode_intervals'
    "#{r.multiplier} #{l("#{s}.#{r.mode}").pluralize(r.multiplier)}"
  end

  def creation_mode(r)
    r.creation_mode.to_s.tr('_', ' ')
  end

  def anchor_mode(r)
    s = 'issues.recurrences.form'
    t = "#{l("issue_recurrences.index.anchor_modes.#{r.anchor_mode}")}" \
      " #{strip_tags(l("#{s}.anchor_to_start.#{r.anchor_to_start}"))}"
    t += r.delay_multiplier > 0 ? " + #{r.delay_multiplier}" \
      " #{l("#{s}.delay_intervals.#{r.delay_mode}").pluralize(r.delay_multiplier)}" : ''
    t
  end

  # Spent time > Report: hours per series and month, over the last year.
  def recurrence_series_report_path(project)
    report_project_time_entries_path(project, 'issue.recurrence_of' => '*',
                                     'spent_on' => '>t-365', criteria: ['recurrence_of'],
                                     columns: 'month')
  end

  def series_estimated_hours(series)
    return if series.template.disabled_core_fields.include?('estimated_hours')

    series.estimated_hours
  end

  # Totals over the series of the list, in core's query totals markup.
  def recurrence_series_totals_tag(series, spent_time)
    estimated = series.filter_map { |s| series_estimated_hours(s) }
    totals = [[l(:field_estimated_hours), 'estimated-hours', estimated.sum]]
    totals << [l(:label_spent_time), 'spent-hours', series.sum(&:spent_hours)] if spent_time
    tags = totals.map do |label, css, value|
      content_tag('span', safe_join([content_tag('span', "#{label}:"), ' ',
                                     content_tag('span', format_hours(value), class: 'value')]),
                  class: "total-for-#{css}")
    end
    content_tag('p', safe_join(tags, ' '), class: 'query-totals')
  end

  def limit_condition(r)
    return "-" if r.date_limit.nil? && r.count_limit.nil?
    return "date: #{r.date_limit}" if r.date_limit.present?
    return "count: #{r.count_limit}" if r.count_limit.present?
  end
end
