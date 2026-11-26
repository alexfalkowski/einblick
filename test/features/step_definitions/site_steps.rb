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

Given('an acknowledged {string} request log with status {string} and duration {string}') do |protocol, status, duration|
  prepare_request_log(protocol, status, duration)
end

Given('acknowledged logs with related requests of different severities and messages') do
  prepare_related_log_search
end

Given('acknowledged logs without an event time, one with an observation time') do
  prepare_logs_without_event_time
end

Given('acknowledged recent logs with matching requests and other messages, severities and traces') do
  prepare_recent_filtered_logs
end

When('I open the Logs page and load its assets') do
  open_logs_with_assets
end

When('I choose the {string} time range') do |preset|
  choose_time_range(preset)
end

When('I choose {string} with a {int}-minute query limit') do |preset, minutes|
  choose_configured_time_range(preset, minutes)
end

When('I submit the displayed search filters') do
  submit_displayed_search
end

When('I repeat a search for the {string} range after a new log arrives in the {string} view') do |range, layout|
  repeat_search_after_log_arrives(range, layout)
end

When('I reload the {string} search link after a new log arrives') do |range|
  repeat_search_after_log_arrives(range, 'full', reload: true)
end

When('I clear the message filter before rerunning a one-hour search after a new log arrives') do
  clear_message_then_refresh
end

When('I open a saved search from {string} to {string}') do |start_time, end_time|
  open_saved_search(start_time, end_time)
end

When('I open an old bookmark with UTC picker bounds {string} and {string}') do |start_utc, end_utc|
  open_utc_bookmark(start_utc, end_utc)
end

When('I investigate them in a {string} view with browser languages {string}') do |layout, languages|
  investigate_logs(layout, languages)
end

When('I investigate it in the Logs page') do
  investigate_logs('full', 'en')
end

When(/^I submit the browser filters (\{.*\})$/) do |filters|
  submit_browser_filters(filters)
end

When('I search for the literal markup in that message') do
  investigate_logs('partial', 'en', 'text' => Einblick::Site::MARKUP_TERM)
end

When('I clear a message search with no matches in the {string} view') do |layout|
  clear_message_search(layout)
end

When('I read the selected logs in two-record pages') do
  read_log_pages
end

When('I choose the last 15 minutes and follow Next page without htmx') do
  search_and_page_without_htmx
end

When('I reload the paged search link after a matching log arrives') do
  refresh_paged_search
end

When('I find related logs from a later page of an active message and severity search') do
  find_related_logs
end

When('I find related logs from a 15-minute search') do
  find_recent_related_logs
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

Then('I should see the available time presets and the five severity choices') do
  expect(@response).to show_time_and_severity_controls
end

Then('the stylesheet and script URLs should identify the content they serve') do
  expect(@log_assets).to serve_fingerprinted_log_assets
end

Then('I should see the Einblick icon in the browser tab') do
  expect(@favicon).to serve_png_icon
end

Then('the query link should preserve the {string} window of {int} minutes ending now for the selected service') do |preset, minutes|
  expect(@response).to preserve_recent_window(preset, minutes * 60, @preset_started..@preset_finished, @query.slice('service'))
end

Then('{string} should be the only available preset and should search the last {int} minutes') do |preset, minutes|
  expect(@preset_page).to show_only_selected_preset(preset)
  expect(@response).to preserve_recent_window(preset, minutes * 60, @preset_started..@preset_finished)
end

Then('the results should retain the original fractional seconds') do
  expect(@response).to preserve_log_filters(@query)
end

Then('the new log should appear in a refreshed {string} window of {int} hours') do |preset, hours|
  expect(@search_before_arrival).to show_log_messages
  expect(@response).to show_log_messages(Einblick::Site::ARRIVING_MESSAGE)
  expect(@response).to preserve_recent_window(preset, hours * 3600, @search_time, @arrival_filters, @search_layout)
end

Then('the new log should appear in the last 15 minutes') do
  expect(@search_before_arrival).to show_log_messages
  expect(@response).to show_log_messages(Einblick::Site::ARRIVING_MESSAGE)
  expect(@response).to preserve_recent_window('15 min', 900, @search_time, @arrival_filters, 'full')
end

Then('clearing the filter should keep the exact time bounds') do
  expect(@cleared_search).to keep_log_time_bounds(@empty_message_search)
end

Then('the next search should show the new log in a refreshed one-hour window') do
  expect(@response).to show_log_messages(Einblick::Site::ARRIVING_MESSAGE)
  expect(@response).to preserve_recent_window('1 hour', 3600, @search_time, @cleared_filters, 'full')
end

Then('the saved time range should be applied') do
  expect(@response).to show_saved_time_range(@saved_time_range)
end

Then('I should see no matching logs') do
  expect(@response).to show_log_outcome('empty', 'en')
end

Then('the search should use the exact bounds {string} and {string}') do |start_time, end_time|
  bounds = { 'start_time' => start_time, 'end_time' => end_time }
  expect(@response).to show_saved_time_range(bounds).and preserve_log_filters(@query.merge(bounds), 'full')
end

Then('I should see the {string} log view in {string}') do |layout, language|
  expect(@response).to show_log_view(layout, language, 200)
end

Then("I should see the selected service's log messages and exact event times") do
  expect(@response).to show_selected_logs(@query_service, @expected_query_records, @query_receipt_windows)
end

Then("the later query should show the selected service's log messages and exact event times") do
  expect(@response).to show_selected_logs(@query_service, @expected_query_records, @query_receipt_windows)
end

Then('I should only see the log message {string} with severity {string}') do |message, severity|
  expect(@response).to show_log_messages(message).and show_log_severity(severity)
end

Then('the results should keep the exact range and the link should preserve the submitted filters') do
  expect(@response).to preserve_log_filters(@query.merge(@browser_filters))
end

Then('I should see the original message, service and typed log details as text') do
  expect(@response).to show_literal_log(@query_service, Einblick::Site::MARKUP_MESSAGE, Einblick::Site::MARKUP_TERM)
end

Then('I should see which text had no matches and how to clear it') do
  expect(@empty_message_search).to show_empty_message_search(Einblick::Site::MISSING_TERM)
end

Then('the {string} view should show warnings in the same time range for the selected service') do |layout|
  expect(@response).to show_log_view(layout, 'en', 200).and preserve_log_filters(@query.merge('severity' => 'WARN'), layout)
  expect(@response).to show_log_messages("literal %_ ' OR 1=1 --").and show_log_severity('WARN (INFO)')
end

Then('I should see German labels for their details and the original blank values') do
  expect(@response).to show_blank_log_details('Keine Meldung', [" \t", ''])
end

Then('the inspector should show {string} as {string} and the duration as {string}') do |label, status, duration|
  expect(@response).to show_log_request(label, status, duration)
end

Then('I should see each matching log once in newest-first order') do
  expect(@site_pages).to show_log_pages(@query_service, @expected_query_records, @query_receipt_windows, [2, 2, 1])
end

Then('the full pages should show {string} followed by {string} in the same filtered search') do |first_message, next_message|
  filters = @query.except('start_time', 'end_time')
  expect(@native_pages.first).to preserve_recent_window('15 min', 900, @preset_started..@preset_finished, filters, 'full')
  expect(@native_pages).to continue_full_page_log_search(first_message, next_message)
end

Then('reloading should show the new matching log in a refreshed 15-minute window') do
  expect(@response).to show_log_messages(Einblick::Site::PAGED_ARRIVAL_MESSAGE)
  expect(@response).to preserve_recent_window('15 min', 900, @search_time, @query.except('start_time', 'end_time'), 'full')
end

Then('I should see the matching trace with the same time range and filters') do
  filters = @query.merge(Einblick::Site::RELATED_LOG_FILTERS, 'trace_id' => Einblick::Site::FIXTURE_TRACE_ID)
  expect(@response).to show_related_log_search(filters).and show_log_messages('same-time first').and exhaust_log_search
end

Then('the related search should keep the exact interval and reload with the default window') do
  expect(@response).to keep_log_time_bounds(@related_log_source).and offer_default_log_reload
end

Then('the inspector should distinguish observation time from receipt time and show the exact timestamps') do
  expect(@response).to show_log_time_fallbacks(@expected_query_records, @query_receipt_windows)
end

Then('the {string} view should show {string} in {string} with HTTP {int}') do |layout, outcome, language, status|
  expect(@response).to show_log_view(layout, language, status).and show_log_outcome(outcome, language)
end

Then('the failed query should show that log storage is unavailable in German') do
  expect(@unavailable_response).to show_log_view('partial', 'de', 503).and show_log_outcome('unavailable', 'de')
end

Then('I should see a Spanish log timeout') do
  expect(@response).to show_log_view('partial', 'es', 504).and show_log_outcome('timeout', 'es')
end
