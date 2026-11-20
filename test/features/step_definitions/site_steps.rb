# frozen_string_literal: true

Given('an acknowledged log with markup-like content') do
  prepare_markup_log
end

Given('acknowledged logs with blank messages') do
  prepare_blank_logs
end

Given('acknowledged logs beyond the signed nanosecond range') do
  prepare_unsigned_logs
end

When('I open the Logs page') do
  open_logs
end

When('I choose the last hour') do
  choose_last_hour
end

When('I submit the displayed UTC picker values') do
  submit_displayed_utc_range
end

When('I set the UTC pickers to {string} and {string}') do |start_time, end_time|
  choose_utc_range(start_time, end_time)
end

When('I investigate them in a {string} view with browser languages {string}') do |layout, languages|
  investigate_logs(layout, languages)
end

When(/^I submit the browser filters (\{.*\})$/) do |filters|
  submit_browser_filters(filters)
end

When('I investigate it in a partial view') do
  investigate_logs('partial', 'en')
end

When('I read the selected logs in two-record pages') do
  read_log_pages
end

When('I investigate with {string} in a {string} view with browser languages {string}') do |outcome, layout, languages|
  investigate_log_outcome(outcome, layout, languages)
end

When('I submit a query while local log storage is unavailable and try again after recovery') do
  submit_logs_with_storage_unavailable
end

When('my Spanish log query exhausts its budget') do
  submit_logs_with_expired_budget
end

Then('I should see the recent log controls without a sign-in flow') do
  expect(@response.history).to be_empty
  expect(@response).to show_log_view('full', 'en', 200)
end

Then('I should see time presets, UTC pickers and the five severity choices') do
  expect(@response).to show_time_and_severity_controls
end

Then('the query link should fix a one-hour window ending now for the selected service') do
  expect(@response).to preserve_recent_window(3600, @preset_started..@preset_finished, @query_service)
end

Then('the query link should retain the original fractional seconds') do
  expect(@response).to preserve_log_filters(@query)
end

Then('the query link should use the selected UTC bounds') do
  expect(@response).to preserve_log_filters(@query.merge('start_time' => '2026-11-19T11:04:00Z', 'end_time' => '2026-11-19T11:04:04Z'))
end

Then('I should see a readable range with no matching logs') do
  expect(@response).to show_log_outcome('empty', 'en').and show_time_range('19 Nov 2026, 11:04:00', '19 Nov 2026, 11:04:04')
end

Then('I should see the {string} log view in {string}') do |layout, language|
  expect(@response).to show_log_view(layout, language, 200)
end

Then("I should see the selected service's log messages and exact event times") do
  expect(@response).to show_selected_logs(@query_service, @expected_query_records)
end

Then("the later query should show the selected service's log messages and exact event times") do
  expect(@response).to show_selected_logs(@query_service, @expected_query_records)
end

Then('I should only see the log message {string} with severity {string}') do |message, severity|
  expect(@response).to show_log_messages(message).and show_log_severity(severity)
end

Then('the query link should preserve the submitted filters and absolute time range') do
  expect(@response).to preserve_log_filters(@query.merge(@browser_filters))
end

Then('I should see the original message, service and typed log details as text') do
  expect(@response).to show_literal_log(@query_service)
end

Then('I should see German labels for their details and the original blank values') do
  expect(@response).to show_blank_log_details('Keine Meldung', [" \t", ''])
end

Then('I should see each matching log once in newest-first order') do
  expect(@site_pages).to show_log_pages(@query_service, @expected_query_records, [2, 2, 1])
end

Then('the {string} view should show {string} in {string} with HTTP {int}') do |layout, outcome, language, status|
  expect(@response).to show_log_view(layout, language, status).and show_log_outcome(outcome, language)
end

Then('the failed query should show that local storage is unavailable in German') do
  expect(@unavailable_response).to show_log_view('partial', 'de', 503).and show_log_outcome('unavailable', 'de')
end

Then('I should see a Spanish log timeout') do
  expect(@response).to show_log_view('partial', 'es', 504).and show_log_outcome('timeout', 'es')
end
