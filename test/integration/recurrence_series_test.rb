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

  def test_time_report_criterion_needs_view_issue_recurrences
    roles(:developer).remove_permission!(:view_issue_recurrences)
    get report_project_time_entries_path(@project, criteria: ['recurrence_of'], columns: 'year')
    assert_response :success
    assert_select 'select#criterias option[value=recurrence_of]', 0
    assert_select '#time-report', 0
  end
end
