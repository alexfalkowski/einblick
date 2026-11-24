# frozen_string_literal: true

Given('acknowledged searchable logs') do
  prepare_searchable_logs
  expect(@response).to be_a(Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceResponse)
  expect(@response.partial_success).to be_nil
end

Given('the client has read the first recent-log page') do
  prepare_first_log_page
end

Given('a log investigation with substantial native query work') do
  prepare_native_query_work
end

Given('more acknowledged matching logs than fit in the configured page limit') do
  prepare_more_than_one_query_page
  expect(@response).to be_a(Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceResponse)
end

Given('acknowledged labelled and unlabelled logs in an isolated time window') do
  prepare_all_service_query
  expect(@response).to be_a(Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceResponse)
  expect(@response.partial_success).to be_nil
end

Given('two separately acknowledged logs matching a 500 KiB text filter') do
  prepare_large_text_filter_logs
  expect(@large_query_responses).to all(be_a(Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceResponse))
  expect(@large_query_responses).to all(have_attributes(partial_success: nil))
end

When('the client queries recent logs') do
  query_logs
end

When('the client queries recent logs using gRPC') do
  query_grpc_logs
end

When(/^the client queries recent logs using gRPC with (.+)$/) do |parameters|
  query_grpc_logs(JSON.parse(parameters))
end

When('the client continues the HTTP log query using gRPC') do
  continue_logs_using_grpc
end

When('the client reads the matching logs in single-record gRPC pages') do
  query_large_text_filter_pages
end

When('a gRPC log query exhausts its configured budget') do
  query_grpc_with_expired_budget
end

When(/^the client queries recent logs with (.+)$/) do |parameters|
  query_logs(JSON.parse(parameters))
end

When('newer, equal-time and late logs arrive while the client reads the remaining pages') do
  query_pages_during_ingestion
end

When('the client continues the recent-log query after a {string} restart') do |mode|
  query_after_restart(mode)
end

When(/^the client changes the paginated query with (.+)$/) do |parameters|
  query_logs({ 'page_size' => 2, 'page_token' => @first_log_page.next_page_token }.merge(JSON.parse(parameters)))
end

When('the client queries acknowledged logs at the unsigned timestamp boundary') do
  query_full_precision_logs
end

When('the client queries acknowledged logs without event or observed timestamps') do
  query_receipt_time_logs
end

When('a recent-log query exhausts its configured budget and the client retries normally') do
  query_with_expired_budget
end

When('the client queries temporarily unavailable local logs') do
  query_unavailable_storage
end

When('the client queries temporarily unavailable local logs using gRPC') do
  query_unavailable_storage('grpc')
end

When('a long-running native log query times out and the client continues its earlier query') do
  query_with_native_cancellation
end

When('the client reads logs using the default page size') do
  query_default_sized_pages
end

When('the client continues the query with timezone-equivalent bounds') do
  @query['start_time'] = '2026-11-19T12:04:05.123456789+01:00'
  @query['end_time'] = '2026-11-19T12:04:05.123456799+01:00'
  collect_log_pages(@first_log_page)
end

When('the client cancels an active native log query and continues its earlier query') do
  query_with_caller_cancellation
end

When('the client queries logs with the service filter {string}') do |selection|
  query_all_services(selection)
end

Then('the query should return complete matching logs latest first') do
  expect(@response.code).to eq(200)
  page = Einblick::V1::ListLogsResponse.decode_json(@response.body)
  expect(page.logs).to have_queried_logs([@request], @expected_query_records, @query_receipt_windows)
  expect(page.next_page_token).to eq('')
  expect(page.meta['user_agent']).to eq('Einblick-ruby-client/1.0 HTTP/1.0')
end

Then('the gRPC query should return complete matching logs latest first') do
  expect(@grpc_response).to be_a(Einblick::V1::ListLogsResponse)
  expect(@grpc_response.logs).to have_queried_logs([@request], @expected_query_records, @query_receipt_windows)
  expect(@grpc_response.next_page_token).to eq('')
  expect(@grpc_response.meta['request_id']).to eq(@query_request_id)
  expect(@grpc_response.meta['user_agent']).to include('Einblick-ruby-client/1.0 gRPC/1.0')
end

Then('the log query should fail safely with gRPC {int}') do |code|
  expect(@grpc_response).to be_a(GRPC::BadStatus)
  expect(@grpc_response.code).to eq(code)
  descriptions = { 3 => 'invalid argument', 4 => 'deadline exceeded', 14 => 'unavailable' }
  expect(@grpc_response.details).to eq("grpc: #{descriptions.fetch(code)}")
end

Then('the log query should return record positions {string}') do |positions|
  expect(@response.code).to eq(200)
  records = @request.resource_logs.first.scope_logs.first.log_records
  expected = positions.split(',').map { |position| records[Integer(position)] }
  expect(Einblick::V1::ListLogsResponse.decode_json(@response.body).logs).to have_queried_logs([@request], expected, @query_receipt_windows)
end

Then('the log query should return no matches') do
  expect(@response.code).to eq(200)
  page = Einblick::V1::ListLogsResponse.decode_json(@response.body)
  expect(page.logs).to be_empty
  expect(page.next_page_token).to eq('')
end

Then('the log query should fail safely with HTTP {int}') do |code|
  expect(@response.code).to eq(code)
  expect(@response.body.strip).to eq("http: #{code == 400 ? 'bad request' : 'service unavailable'}")
end

Then('pagination should return each original matching log once in order') do
  expect(@query_pages.map { |page| page.logs.size }).to eq([2, 2, 1])
  expect(@query_logs.map(&:id).uniq.size).to eq(5)
  expect(@query_logs).to have_queried_logs([@request], @expected_query_records, @query_receipt_windows)
end

Then('pagination should include arrivals behind the cursor without repeating records') do
  arrivals = @arrival_request.resource_logs.first.scope_logs.first.log_records
  expected = @expected_query_records.dup.insert(2, arrivals[1]).insert(5, arrivals[0])
  expect(@query_pages.map { |page| page.logs.size }).to eq([2, 2, 2, 1])
  expect(@query_logs.map(&:id).uniq.size).to eq(7)
  expect(@query_logs).to have_queried_logs([@request, @arrival_request], expected, @query_receipt_windows)
end

Then('a fresh log query should include the newly acknowledged records') do
  expect(@arrival_response).to be_a(Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceResponse)
  expect(@fresh_query.logs.size).to eq(9)
  expect(@fresh_query.logs.first.record.body.string_value).to eq('arrived 4')
end

Then('the expired log query should time out without a partial page') do
  expect(@timeout_response.code).to eq(504)
  expect(@timeout_response.body.strip).to eq('http: gateway timeout')
  expect(@query_elapsed).to be < 2
end

Then('concurrent log queries should respect the single-query work limit') do
  expect(@concurrent_query_responses.map(&:code)).to eq([504, 504, 504, 504])
  expect(@query_metrics).to have_active_log_query_limit(1)
end

Then('the configured page limit should bound complete results without losing records') do
  expect(@query_pages.map { |page| page.logs.size }).to eq([100, 5])
  expect(@query_pages.last.next_page_token).to eq('')
  expect(@query_logs).to have_queried_logs([@request], @expected_query_records, @query_receipt_windows)
end

Then('the cancelled log query should release native work promptly') do
  expect(@grpc_response).to be_a(GRPC::Cancelled)
  expect([@caller_query_metrics]).to have_active_log_query_limit(0)
end

Then('the unsigned log query should return both exact records across exhausted pages') do
  expect(@response.code).to eq(200)
  expect(@query_pages.map { |page| page.logs.size }).to eq([1, 1])
  expect(@query_pages.first.next_page_token).not_to be_empty
  expect(@query_pages.last.next_page_token).to be_empty
  expect(@query_pages.last.meta['user_agent']).to eq('Einblick-ruby-client/1.0 HTTP/1.0')
  expect(@query_logs.map(&:id).uniq.size).to eq(2)
  expect(@query_logs).to have_queried_logs([@request], @expected_query_records, @query_receipt_windows)
end

Then('the large-filter query should return both complete records across exhausted pages') do
  expect(@query_pages.map { |page| page.logs.size }).to eq([1, 1])
  expect(@query_pages.first.next_page_token).not_to be_empty
  expect(@query_pages.last.next_page_token).to be_empty
  expect(@query_logs.map(&:id).uniq.size).to eq(2)
  expect(@query_logs).to have_queried_logs(@large_query_requests, @expected_query_records, @query_receipt_windows)
end
