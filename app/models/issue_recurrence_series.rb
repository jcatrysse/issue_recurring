# Estimated and spent time of a recurring issue (the template, which carries the
# recurrence schedules) together with all its recurrences.
#
# Every issue belongs to at most one series: a recurrence to the series of its
# recurrence_of, a template to its own, any other issue to the series of its
# nearest ancestor that belongs to one. Filters, columns, the time report and
# the totals all use this one rule, so their numbers agree.
class IssueRecurrenceSeries
  attr_reader :template, :issues_count, :estimated_hours, :spent_hours

  # SQL condition: the issue aliased as +table+ is a template.
  def self.template_condition(table)
    "(EXISTS (SELECT 1 FROM #{IssueRecurrence.table_name} irr WHERE irr.issue_id = #{table}.id)" \
      " OR EXISTS (SELECT 1 FROM #{Issue.table_name} irc WHERE irc.recurrence_of_id = #{table}.id))"
  end

  # SQL expression: id of the template of the series the issue aliased as
  # +table+ belongs to, NULL when it belongs to none.
  def self.template_sql(table = Issue.table_name)
    "(CASE" \
      " WHEN #{table}.recurrence_of_id IS NOT NULL THEN #{table}.recurrence_of_id" \
      " WHEN #{template_condition(table)} THEN #{table}.id" \
      " WHEN #{table}.parent_id IS NOT NULL THEN" \
      " (SELECT COALESCE(ira.recurrence_of_id, ira.id) FROM #{Issue.table_name} ira" \
      " WHERE ira.root_id = #{table}.root_id AND ira.lft < #{table}.lft AND ira.rgt > #{table}.rgt" \
      " AND (ira.recurrence_of_id IS NOT NULL OR #{template_condition('ira')})" \
      " ORDER BY ira.lft DESC LIMIT 1)" \
      " END)"
  end

  def self.templates
    Issue.where(template_condition(Issue.table_name))
  end

  # Whether filters, columns and report criteria on series are offered in
  # +project+ (any project when nil).
  def self.visible_in?(project)
    User.current.allowed_to?(:view_issue_recurrences, project, global: project.nil?)
  end

  # Filter values: the templates the user can see in +project+ (and its
  # subprojects as Redmine displays them), in any project when nil, as far as
  # the user may view recurrences there.
  def self.template_values(project)
    scope = templates.visible.where(Project.allowed_to_condition(User.current, :view_issue_recurrences))
    scope = scope.where(project.project_condition(Setting.display_subprojects_issues?)) if project
    scope.order(:id).pluck(:id, :subject).map { |id, subject| ["##{id}: #{subject}", id.to_s] }
  end

  # Ids of the issues of each series, by template id. Only the subtrees of the
  # template and its recurrences are looked at, not the rest of their trees.
  def self.issue_ids_by_template(template_ids)
    template_ids = template_ids.map(&:to_i).to_set
    return {} if template_ids.empty?

    subtrees = Issue.where(id: template_ids.to_a)
      .or(Issue.where(recurrence_of_id: template_ids.to_a))
      .pluck(:root_id, :lft, :rgt)
      .group_by(&:first)
      .transform_values { |rows| merge_ranges(rows.map { |_, lft, rgt| [lft, rgt] }) }
    candidate_ids = Issue.where(root_id: subtrees.keys).pluck(:id, :root_id, :lft)
      .select { |_, root_id, lft| in_ranges?(subtrees[root_id], lft) }
      .map(&:first)
    rows = Issue.where(id: candidate_ids).pluck(:id, Arel.sql(template_sql))
    rows.each_with_object({}) do |(id, template_id), ids|
      next unless template_id && template_ids.include?(template_id.to_i)

      (ids[template_id.to_i] ||= []) << id
    end
  end

  # Sorted, non-overlapping [lft, rgt] ranges covering +ranges+.
  def self.merge_ranges(ranges)
    ranges.sort.each_with_object([]) do |(lft, rgt), merged|
      if merged.any? && lft <= merged.last[1]
        merged.last[1] = [merged.last[1], rgt].max
      else
        merged << [lft, rgt]
      end
    end
  end

  def self.in_ranges?(ranges, lft)
    i = (ranges.bsearch_index { |l, _| l > lft } || ranges.size) - 1
    i >= 0 && lft <= ranges[i][1]
  end

  # SQL condition for the filter "Recurrence of" on the issue id in +column+.
  # The issues table must be joined as issues, restricted to visible issues
  # where the query does that (time entries), so all operators agree.
  def self.sql_for_filter(column, operator, value)
    case operator
    when '='
      ids = issue_ids_by_template(value).values.flatten
      ids.any? ? "#{column} IN (#{ids.join(',')})" : '1=0'
    when '!'
      ids = issue_ids_by_template(value).values.flatten
      ids.any? ? "(#{column} IS NULL OR #{column} NOT IN (#{ids.join(',')}))" : '1=1'
    when '*'
      "#{template_sql} IS NOT NULL"
    when '!*'
      "#{template_sql} IS NULL"
    end
  end

  # The series +issue+ belongs to, nil when none.
  def self.for_issue(issue)
    template_id = Issue.where(id: issue.id).pick(Arel.sql(template_sql))
    return if template_id.nil?

    template = template_id == issue.id ? issue : Issue.find_by(id: template_id)
    for_templates([template])[template.id] if template
  end

  # The series of +templates+, by template id, computed in a fixed number of
  # queries. Hours of the time entries the user can see on the issues the user
  # can see, as Spent time filtered on the series lists them; estimated time and
  # count of those issues; subtask copies are not counted separately.
  def self.for_templates(templates)
    ids_by_template = issue_ids_by_template(templates.map(&:id))
    ids = ids_by_template.values.flatten
    hours = TimeEntry.visible.where(issue_id: ids).group(:issue_id).sum(:hours)
    issues = Issue.visible.where(id: ids)
      .pluck(:id, :parent_id, :recurrence_of_id, :estimated_hours, :project_id)
      .index_by(&:first)

    templates.each_with_object({}) do |template, series|
      series_ids = ids_by_template[template.id] || []
      visible = issues.values_at(*series_ids).compact
      member_ids = series_ids.to_set
      counted = visible.select do |id, parent_id, recurrence_of_id|
        id == template.id ||
          (recurrence_of_id == template.id && !member_ids.include?(parent_id))
      end
      estimated = visible.filter_map { |row| row[3] }
      series[template.id] = new(
        template,
        issues_count: counted.size,
        estimated_hours: estimated.empty? ? nil : estimated.sum.to_f,
        spent_hours: hours.values_at(*visible.map(&:first)).compact.sum.to_f,
        project_ids: visible.map(&:last).uniq
      )
    end
  end

  def initialize(template, issues_count:, estimated_hours:, spent_hours:, project_ids:)
    @template = template
    @issues_count = issues_count
    @estimated_hours = estimated_hours
    @spent_hours = spent_hours
    @project_ids = project_ids
  end

  # Whether every issue of the series the user can see is in the template's project.
  def single_project?
    (@project_ids - [template.project_id]).empty?
  end
end
