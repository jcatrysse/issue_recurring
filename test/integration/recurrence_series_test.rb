require_relative '../test_helper'
require_relative '../recurrence_series_helper'

class RecurrenceSeriesTest < IssueRecurringIntegrationTestCase
  include RecurrenceSeriesHelper

  def setup
    super
    User.current = users(:alice)
    build_series
    log_series_time
    User.current = nil
    @project = projects(:project_01)
    log_user 'alice', 'foo'
  end

  def teardown
    super
    logout_user
  end

  def series_filter(operator, values = [])
    {set_filter: 1, f: ['issue.recurrence_of'], op: {'issue.recurrence_of' => operator},
     v: {'issue.recurrence_of' => values}, t: ['hours']}
  end

  def assert_total_hours(expected)
    assert_select 'p.query-totals .total-for-hours .value', expected
  end

  def test_time_entries_filter_is_template
    with_settings timespan_format: 'decimal' do
      get project_time_entries_path(@project, 'issue.recurrence_of' => @template.id, t: ['hours'])
      assert_response :success
      assert_total_hours '21.00'
      assert_select 'table.time-entries tbody tr', 6
    end
  end

  def test_time_entries_filter_operators
    with_settings timespan_format: 'decimal' do
      get project_time_entries_path(@project, series_filter('!', [@template.id]))
      assert_total_hours '7.00'
      get project_time_entries_path(@project, series_filter('*'))
      assert_total_hours '21.00'
      get project_time_entries_path(@project, series_filter('!*'))
      assert_total_hours '7.00'
    end
  end

  def test_time_entries_filter_operators_with_two_series
    build_second_series
    with_settings timespan_format: 'decimal' do
      get project_time_entries_path(@project, series_filter('=', [@template.id]))
      assert_total_hours '21.00'
      get project_time_entries_path(@project, series_filter('=', [@template.id, @template2.id]))
      assert_total_hours '26.00'
      get project_time_entries_path(@project, series_filter('!', [@template.id]))
      assert_total_hours '12.00'
      get project_time_entries_path(@project, series_filter('*'))
      assert_total_hours '26.00'
      get project_time_entries_path(@project, series_filter('!*'))
      assert_total_hours '7.00'
    end
  end

  # Spent time joins an issue only when the user can see it; time on a private
  # recurrence of someone else is then outside every series, everywhere.
  def test_time_on_issues_the_user_cannot_see
    @copy2.update_columns(is_private: true, assigned_to_id: users(:bob).id)
    assert_not @copy2.reload.visible?(users(:alice))
    with_settings timespan_format: 'decimal' do
      get project_time_entries_path(@project, series_filter('=', [@template.id]))
      assert_total_hours '15.00'
      get project_time_entries_path(@project, series_filter('*'))
      assert_total_hours '15.00'
      get project_time_entries_path(@project, series_filter('!*'))
      assert_total_hours '13.00'
      get report_project_time_entries_path(@project, criteria: ['recurrence_of'], columns: 'year')
      template_row = css_select('#time-report tr.last-level').detect { |row| row.at_css('td.name a') }
      assert_equal '15.00', template_row.css('td.hours').last.text.strip
      get issue_path(@copy1)
      assert_select '#issue_recurrences p.recurrence-series',
        text: 'Total (2 issues): Estimated time: 7.00 h, Spent time: 15.00 h'
      get project_recurrences_path(@project)
      assert_select '#project_recurrences td.spent_hours', '15.00'
      get project_time_entries_path(@project, set_filter: 1, f: ['spent_on'], op: {spent_on: '*'},
                                    c: ['issue', 'recurrence_of', 'hours'], t: ['hours'],
                                    group_by: 'recurrence_of')
      template_group = css_select('tr.group').detect { |g| g.at_css('span.name a') }
      assert_equal '15.00', template_group.at_css('.total-for-hours .value').text
      assert_select 'table.time-entries td.recurrence_of a[href=?]', issue_path(@template), 5
    end
  end

  def test_time_entries_filter_values_are_visible_templates
    get '/queries/filter', params: {project_id: @project.id, type: 'TimeEntryQuery',
                                    name: 'issue.recurrence_of'}
    assert_response :success
    assert_equal [["##{@template.id}: #{@template.subject}", @template.id.to_s]],
      JSON.parse(response.body)
  end

  def test_time_entries_filter_needs_view_issue_recurrences
    roles(:developer).remove_permission!(:view_issue_recurrences)
    with_settings timespan_format: 'decimal' do
      get project_time_entries_path(@project, 'issue.recurrence_of' => @template.id, t: ['hours'])
      assert_response :success
      assert_total_hours '28.00'
      assert_not_includes css_select('script').map(&:text).join, '"issue.recurrence_of"'
    end
  end

  def test_time_entries_api_with_filter
    with_settings rest_api_enabled: '1' do
      logout_user
      get "/projects/#{@project.identifier}/time_entries.json",
        params: series_filter('=', [@template.id]), headers: credentials('alice', 'foo')
      assert_response :success
      assert_equal 6, JSON.parse(response.body)['total_count']
    end
  end

  def test_time_report_by_recurrence_of
    with_settings timespan_format: 'decimal' do
      get report_project_time_entries_path(@project, criteria: ['recurrence_of'], columns: 'year')
      assert_response :success
      assert_select '#time-report tr.last-level' do |rows|
        template_row = rows.detect { |row| row.css('td.name a').any? }
        assert_equal issue_path(@template), template_row.at_css('td.name a')['href']
        assert_equal '21.00', template_row.css('td.hours').last.text.strip
      end
      assert_select '#time-report tr.last-level td.name', text: "[#{I18n.t(:label_none)}]"
    end
  end

  def test_time_report_csv_by_recurrence_of
    with_settings timespan_format: 'decimal' do
      get report_project_time_entries_path(@project, criteria: ['recurrence_of'], columns: 'year',
                                           format: 'csv')
      assert_response :success
      line = response.body.lines.detect { |l| l.include?("##{@template.id}") }
      assert line, response.body
      assert_includes line, '21.00'
    end
  end

  def test_issue_page_shows_series_totals_on_every_issue_of_the_series
    with_settings timespan_format: 'decimal' do
      [@template, @copy1, @manual].each do |issue|
        get issue_path(issue)
        assert_response :success
        assert_select '#issue_recurrences p.recurrence-series',
          text: 'Total (3 issues): Estimated time: 9.00 h, Spent time: 21.00 h'
        assert_select '#issue_recurrences p.recurrence-series a[href=?]',
          project_time_entries_path(@project, 'issue.recurrence_of' => @template.id), text: '21.00 h'
      end
    end
  end

  def test_issue_page_series_link_shows_the_same_total
    with_settings timespan_format: 'decimal' do
      get issue_path(@copy2)
      href = css_select('#issue_recurrences p.recurrence-series a').first['href']
      get href, params: {t: ['hours']}
      assert_total_hours '21.00'
    end
  end

  def test_issue_page_without_series
    get issue_path(@other)
    assert_response :success
    assert_select '#issue_recurrences'
    assert_select '#issue_recurrences p.recurrence-series', 0
  end

  def test_issue_page_series_totals_without_view_time_entries
    roles(:developer).remove_permission!(:view_time_entries)
    with_settings timespan_format: 'decimal' do
      get issue_path(@copy1)
      assert_select '#issue_recurrences p.recurrence-series',
        text: 'Total (3 issues): Estimated time: 9.00 h'
    end
  end

  def test_issue_page_series_totals_without_estimated_time_field
    @template.tracker.update!(core_fields: Tracker::CORE_FIELDS - ['estimated_hours'])
    with_settings timespan_format: 'decimal' do
      get issue_path(@copy1)
      assert_select '#issue_recurrences p.recurrence-series',
        text: 'Total (3 issues): Spent time: 21.00 h'
    end
  end

  def test_issue_page_series_across_projects_links_to_all_time_entries
    project2 = Project.create!(name: 'Other', identifier: 'other-project', is_public: true,
                               enabled_module_names: %w(issue_tracking time_tracking),
                               tracker_ids: [@template.tracker_id])
    @copy2.update!(project: project2)
    get issue_path(@copy1)
    assert_select '#issue_recurrences p.recurrence-series a[href=?]',
      time_entries_path('issue.recurrence_of' => @template.id)
  end

  def test_module_tab_series_totals_once_per_issue
    schedule(@template, mode: :weekly)
    with_settings timespan_format: 'decimal' do
      get project_recurrences_path(@project)
      assert_response :success
      rows = css_select('#project_recurrences tbody tr')
      assert_equal 2, rows.size
      assert_equal ['9.00', '21.00'],
        rows.first.css('td.estimated_hours, td.spent_hours').map { |td| td.text.strip }
      assert_equal project_time_entries_path(@project, 'issue.recurrence_of' => @template.id),
        rows.first.at_css('td.spent_hours a')['href']
      assert_equal ['', ''],
        rows.last.css('td.estimated_hours, td.spent_hours').map { |td| td.text.strip }
      assert_select 'p.query-totals .total-for-estimated-hours .value', '9.00'
      assert_select 'p.query-totals .total-for-spent-hours .value', '21.00'
    end
  end

  def test_module_tab_report_link
    build_second_series
    with_settings timespan_format: 'decimal' do
      get project_recurrences_path(@project)
      href = css_select('#content .contextual a').detect { |a| a.text == 'Report' }['href']
      get href
      assert_response :success
      assert_select '#time-report tr.last-level', 2
      assert_equal ['21.00', '5.00'], [@template, @template2].map { |t|
        css_select('#time-report tr.last-level')
          .detect { |row| row.at_css("td.name a[href='#{issue_path(t)}']") }
          .css('td.hours').last.text.strip
      }
    end
  end

  def test_module_tab_without_view_time_entries
    roles(:developer).remove_permission!(:view_time_entries)
    with_settings timespan_format: 'decimal' do
      get project_recurrences_path(@project)
      assert_response :success
      assert_select '#project_recurrences td.estimated_hours', '9.00'
      assert_select '#project_recurrences td.spent_hours', 0
      assert_select '#content .contextual a', text: 'Report', count: 0
      assert_select 'p.query-totals .total-for-spent-hours', 0
    end
  end

  def issues_filter(operator, values = [], **options)
    {set_filter: 1, f: ['status_id', 'recurrence_of'], op: {status_id: '*', recurrence_of: operator},
     v: {recurrence_of: values}, c: ['subject', 'recurrence_of', 'estimated_hours', 'spent_hours'],
     t: ['estimated_hours', 'spent_hours']}.merge(options)
  end

  def test_issue_list_filter_and_column
    with_settings timespan_format: 'decimal' do
      get project_issues_path(@project, issues_filter('=', [@template.id]))
      assert_response :success
      assert_select 'table.issues tr.issue', 7
      assert_select 'table.issues td.recurrence_of a[href=?]', issue_path(@template), 7
      assert_select 'p.query-totals .total-for-estimated-hours .value', '9.00'
      assert_select 'p.query-totals .total-for-spent-hours .value', '21.00'
    end
  end

  def test_issue_list_filter_none
    get project_issues_path(@project, issues_filter('!*'))
    assert_response :success
    assert_equal [@other.id, issues(:issue_03).id].sort,
      css_select('table.issues tr.issue').map { |tr| tr['id'].delete_prefix('issue-').to_i }.sort
    assert_select 'table.issues td.recurrence_of', text: '', count: 2
  end

  def test_issue_list_grouped_by_recurrence_of
    with_settings timespan_format: 'decimal' do
      get project_issues_path(@project, issues_filter('*', [], group_by: 'recurrence_of'))
      assert_response :success
      assert_select 'tr.group', 1
      assert_select 'tr.group span.name a[href=?]', issue_path(@template)
      assert_select 'tr.group span.count', '7'
      assert_select 'tr.group .total-for-spent-hours .value', '21.00'
    end
  end

  def test_issue_list_grouped_by_recurrence_of_with_two_series
    build_second_series
    get project_issues_path(@project, set_filter: 1, f: ['status_id'], op: {status_id: '*'},
                            c: ['subject', 'spent_hours'], group_by: 'recurrence_of')
    assert_response :success
    counts = css_select('tr.group').to_h do |g|
      link = g.at_css('span.name a')
      [link ? link['href'] : 'blank', g.at_css('span.count').text]
    end
    assert_equal({issue_path(@template) => '7', issue_path(@template2) => '2', 'blank' => '1'},
                 counts)
  end

  def test_issue_list_needs_view_issue_recurrences
    roles(:developer).remove_permission!(:view_issue_recurrences)
    get project_issues_path(@project, issues_filter('=', [@template.id]))
    assert_response :success
    assert_select 'table.issues th', text: 'Recurrence of', count: 0
    assert_select 'table.issues tr.issue', 9
  end

  def test_time_entry_list_column_grouped
    with_settings timespan_format: 'decimal' do
      get project_time_entries_path(@project, set_filter: 1, f: ['spent_on'], op: {spent_on: '*'},
                                    c: ['issue', 'recurrence_of', 'hours'], t: ['hours'],
                                    group_by: 'recurrence_of')
      assert_response :success
      groups = css_select('tr.group')
      assert_equal 2, groups.size
      template_group = groups.detect { |g| g.at_css('span.name a') }
      assert_equal issue_path(@template), template_group.at_css('span.name a')['href']
      assert_equal '6', template_group.at_css('span.count').text
      assert_equal '21.00', template_group.at_css('.total-for-hours .value').text
      assert_select 'table.time-entries td.recurrence_of a[href=?]', issue_path(@template), 6
    end
  end

  def test_time_entry_list_csv_with_column
    get project_time_entries_path(@project, set_filter: 1, f: ['spent_on'], op: {spent_on: '*'},
                                  c: ['issue', 'recurrence_of', 'hours'], format: 'csv')
    assert_response :success
    lines = response.body.lines
    assert_includes lines.first, 'Recurrence of'
    assert_equal 6, lines.count { |l| l.include?("##{@template.id}") }
  end

  def test_time_report_criterion_needs_view_issue_recurrences
    roles(:developer).remove_permission!(:view_issue_recurrences)
    get report_project_time_entries_path(@project, criteria: ['recurrence_of'], columns: 'year')
    assert_response :success
    assert_select 'select#criterias option[value=recurrence_of]', 0
    assert_select '#time-report', 0
  end
end
