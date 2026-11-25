# frozen_string_literal: true

Given('a client has the first page of acknowledged logs before archival') do
  prepare_paged_archive_query
end

Given('acknowledged logs are ready to archive') do
  prepare_archive_storage
  prepare_searchable_logs
end

Given('acknowledged recent logs on the server') do
  prepare_archive_storage
  prepare_recent_filtered_logs
end

Given('an acknowledged export was split into batches that share resource and scope context') do
  prepare_shared_context_batches
end

Given('backlog reads can be slowed within the running service') do
  prepare_backlog_query_work
end

Given('acknowledged logs span the daily archive cutoff and include a late arrival') do
  prepare_daily_logs
end

Given('{int} acknowledged logs for a closed day share a large resource') do |count|
  prepare_large_daily_logs(count)
end

When('the client continues the search during publication overlap and after local eviction') do
  continue_across_eviction
end

When('the archive is published and the client searches from a fresh database volume') do
  query_fresh_archive
end

When('the archive is published and the client searches during an object store outage') do
  query_fresh_archive(failure: true)
end

When('the operator searches the last 24 hours during an archive outage') do
  search_recent_logs_during_archive_outage
end

When('the operator searches during an archive outage and retries after recovery') do
  search_history_during_archive_outage
end

When('the worker evicts the archived logs and the operator reopens the database without R2') do
  search_after_removing_archive_configuration
end

When('a slow backlog read times out after the operator has seen pending records') do
  capture_failed_backlog_refreshes
end

When('archive objects disappear and the operator changes the query retention setting') do
  search_after_archive_expiration
end

When('an eligible archive object disappears and the follow-up listing fails') do
  search_after_expiration_listing_failure
end

When('a fresh volume searches while an expired object and a younger object disappear') do
  search_after_younger_archive_loss
end

When('an older evicted batch expires during an archive search and the operator searches again') do
  search_with_unknown_archive_age
end

When('the archive is published and the client searches while the object store briefly fails to list archives') do
  query_after_archive_listing_failure
end

When('the worker publishes ready logs after a listing failure opens the search circuit breaker') do
  publish_while_archive_listings_are_unavailable
end

When('the client cancels an active archive query, searches while it drains, and retries') do
  query_after_archive_cancellation
end

When('a fresh volume accepts the same logs and evicts them after the client reads the first page') do
  query_duplicate_archive_ids
end

When('another batch is evicted while the client is reading archived logs') do
  query_during_archive_eviction
end

When('the client receives an archive listing captured before another batch was published and evicted') do
  query_across_stale_listing
end

When('the first published archive object is {string} before local eviction and the client searches afterward') do |fault|
  evict_with_unverified_archive(fault)
end

When('one batch is evicted while the other is waiting to publish') do
  query_with_local_sibling_batch
end

When('the client searches the same volume after one matching evicted archive object disappears') do
  query_after_archive_loss
end

When('the worker archives the late arrival and the newer archives become unreadable after the first page') do
  publish_daily_logs
end

When('the worker archives the day with local eviction enabled') do
  publish_large_daily_logs
end

Then('one remote Parquet file should contain every acknowledged log for the day') do
  expect(@large_daily_archive_keys.size).to eq(1)
  expect(@large_daily_archive_timestamps).to eq(log_query_records(@archive_request).map(&:time_unix_nano))
end

Then('the archive file should use bounded Parquet row groups') do
  expect(@largest_daily_archive_group).to be <= 7
end

Then('the first page should find the archived days with one listing request') do
  expect(@daily_initial_listings).to eq(1)
end

Then('a paginated search should include every acknowledged log once') do
  expect(@query_logs.map(&:record)).to match_array(@daily_records)
end

Then('the late arrival should remain local until it can be archived') do
  expect(@daily_events_before_supplement).to match_array(@daily_records.last(3).map(&:time_unix_nano))
  expect(@daily_events_after_supplement).to match_array(@daily_records.last(2).map(&:time_unix_nano))
end

Then('the client should read each matching typed log once in the same order') do
  expect(@query_logs).to have_queried_logs([@request], @expected_query_records, @query_receipt_windows)
  expect(@overlap_query_logs).to eq(@query_logs)
end

Then('the active page should contain both batches exactly once') do
  expect(@grpc_response).to be_a(Einblick::V1::ListLogsResponse)
  ids = @grpc_response.logs.map(&:id)
  expect(ids.size).to eq(2 * @expected_query_records.size)
  expect(ids.uniq).to eq(ids)
end

Then('eviction should reclaim the local batch and its unused context') do
  expect(@batch_eviction_status.values).to eq([true])
  expect(@local_archive_members).to be_empty
  expect(@local_archive_rows.values).to all(be_empty)
end

Then('eviction should reclaim the later batch and retain the earlier batch locally') do
  expect(@batch_eviction_status).to eq(@retained_batch_id => false, @evicted_batch_id => true)
  expect(@local_archive_rows.fetch('logs').size).to eq(@retained_archive_record_count)
  expect(@local_archive_members).to retain_archive_members(@retained_batch_id, @local_archive_rows.fetch('logs'))
end

Then('the search should return both batches exactly once') do
  expect(@logs_after_fault).to eq(@logs_before_fault)
  ids = @logs_after_fault.map(&:id)
  expect(ids.size).to eq(2 * @expected_query_records.size)
  expect(ids.uniq).to eq(ids)
end

Then('all original logs and their typed context should remain queryable') do
  expect(@batch_eviction_status).to eq(@retained_batch_id => false, @evicted_batch_id => true)
  expect(@shared_context_logs_before_eviction.size).to eq(3)
  expect(@shared_context_logs_after_eviction).to eq(@shared_context_logs_before_eviction)
end

Then('the archive should supply the complete matching logs') do
  expect(@response.code).to eq(200)
  page = Einblick::V1::ListLogsResponse.decode_json(@response.body)
  expect(page.logs).to have_queried_logs([@request], @expected_query_records, @query_receipt_windows)
end

Then('pagination should include both copies of every matching log') do
  expect(@first_log_page.logs).to have_queried_logs([@request], @expected_query_records.take(1), @foreign_receipt_windows)
  expect(@logs_before_eviction).to include_both_archive_copies(@expected_query_records.size)
  expect(@query_logs).to eq(@logs_before_eviction)
end

Then('the fresh instance should leave the original archive objects unchanged') do
  expect(@discovered_archive_objects).to eq(@original_archive_objects)
end

Then('the Logs page should continue to the next archived log') do
  expect(@archive_next_page.code).to eq(200)
  expect(@archive_next_page).to show_selected_logs(@query_service, @expected_query_records[1, 1], @query_receipt_windows)
end

Then('the log query should report unavailable history') do
  expect(@response.code).to eq(503)
end

Then('the Logs page should report that log storage is unavailable') do
  expect(@archive_outage_view).to show_log_view('full', 'en', 503)
  expect(@archive_outage_fragment).to show_log_view('partial', 'en', 503).and show_log_outcome('unavailable', 'en')
end

Then('the API should report unavailable history for the older range') do
  expect(@archive_outage_api_response.code).to eq(503)
end

Then('the default recent search should still succeed') do
  expect(@recent_logs_view).to show_log_view('full', 'en', 200)
end

Then('the retried search should return the matching logs') do
  expect(@recovered_history_view.code).to eq(200)
  expect(@recovered_history_view).to show_selected_logs(@query_service, @expected_query_records.take(1), @query_receipt_windows)
end

Then('the Logs page should show the recent logs') do
  expect(@recent_logs_view.code).to eq(200)
  expect(@recent_logs_view).to show_selected_logs(@query_service, [@expected_query_records.fetch(3)], @query_receipt_windows)
end

Then('the API should return each matching recent log across pages') do
  expect(@recent_log_page.next_page_token).not_to be_empty
  expect(@recent_log_next_page.next_page_token).to be_empty
  results = @recent_log_page.logs.to_a + @recent_log_next_page.logs.to_a
  expect(results).to have_queried_logs([@request], @expected_query_records.last(2), @query_receipt_windows)
  expect(@oversized_token_response.code).to eq(400)
end

Then('publication recovery should drain the visible log backlog') do
  expect(@archive_metrics_during_outage).to have_archive_backlog(
    'pending_records' => @query_record_count, 'pending_size_bytes' => be_positive,
    'pending_oldest_age_seconds' => be_positive, 'last_publication_timestamp_seconds' => 0
  )
  published_during_recovery = be_between(@archive_recovery_window.begin, @archive_recovery_window.end)
  expect(@archive_metrics_after_recovery).to have_archive_backlog(
    'pending_records' => 0, 'pending_size_bytes' => 0,
    'pending_oldest_age_seconds' => 0, 'last_publication_timestamp_seconds' => published_during_recovery
  )
end

Then('the metrics endpoint should withdraw the previous backlog sample after the timeout') do
  expect(@archive_metrics_during_outage).to have_archive_backlog('pending_records' => @query_record_count)
  expect(@metrics_after_backlog_timeout).to omit_archive_backlog_gauges
end

Then('the sampler should rest after a slow read') do
  expect(@backlog_refresh_diagnostics).to have_backlog_refresh_failures(2, interval: 0.1)
end

Then('a metrics scrape during the first slow read should report the previous backlog count') do
  expect(@backlog_scrapes).to have_cached_backlog_during_first_read(@backlog_refresh_diagnostics, @query_record_count)
end

Then('the search should return the remaining history') do
  expect(@logs_before_expiration.size).to eq(2 * @expected_query_records.size)
  expect(@search_during_expiration).to be_a(Einblick::V1::ListLogsResponse)
  expect(@search_during_expiration.logs.to_a).to eq(@logs_after_expiration)
  expect(@logs_after_expiration).to have_queried_logs([@request], @expected_query_records, @query_receipt_windows)
end

Then('the active search should return the remaining history') do
  expect(@search_during_expiration).to be_a(Einblick::V1::ListLogsResponse)
  expect(@search_during_expiration.logs).to have_queried_logs([@request], @expected_query_records, @query_receipt_windows)
end

Then('the active search should report unavailable history') do
  expect(@search_during_expiration).to be_a(GRPC::Unavailable)
  expect(@expiration_listing_diagnostics).to include('refresh log archive')
end

Then('the search should report unavailable history after refreshing the archive listing') do
  expect(@search_during_expiration).to be_a(GRPC::Unavailable)
  expect(@loss_retry_listings).to eq(2)
end

Then("the later search should report unavailable history when the missing object's age is unknown") do
  expect(@response.code).to eq(503)
end

Then('a missing object still within retention should report unavailable history') do
  expect(@response.code).to eq(503)
end

Then('disabling query expiration should require the missing object again') do
  expect(@retention_disabled_response.code).to eq(503)
end

Then('the search should have returned both copies of the matching logs before the loss') do
  expect(@logs_before_archive_loss.size).to eq(2 * @expected_query_records.size)
  expect(@available_archive_keys.size).to eq(1)
end

Then('the cancelled archive query should return gRPC cancelled') do
  expect(@grpc_response).to be_a(GRPC::Cancelled)
end

Then('the recent search should return its records while the archive read is still held') do
  expect(@archive_read_remained_held).to be(true)
  expect(@local_stall_response.code).to eq(200)
  page = Einblick::V1::ListLogsResponse.decode_json(@local_stall_response.body)
  expect(page.logs).to have_queried_logs([@local_stall_request], @local_stall_records, @local_stall_receipts)
end

Then('the queued search should end without listing the archive') do
  # gRPC can reset the stream as the client deadline expires.
  expect(@queued_archive_response).to be_a(GRPC::DeadlineExceeded).or be_a(GRPC::Cancelled)
  expect(@listings_while_archive_query_drained).to eq(0)
end
