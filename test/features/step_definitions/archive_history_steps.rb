# frozen_string_literal: true

Given('a client has the first page of acknowledged logs before archival') do
  prepare_paged_archive_query
end

Given('acknowledged logs are ready to archive') do
  prepare_archive_storage
  prepare_searchable_logs
end

Given('an acknowledged export was split into batches that share resource and scope context') do
  prepare_shared_context_batches
end

Given('backlog reads can be slowed within the running service') do
  prepare_backlog_query_work
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

When('the object store is unavailable and the operator searches local logs') do
  search_local_logs_during_archive_outage
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
  search_after_legacy_archive_expiration
end

When('the archive is published and the client searches while the object store briefly fails to list archives') do
  query_after_archive_listing_failure
end

When('the service accepts logs after a listing failure opens the search circuit breaker') do
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

When('the worker evicts eligible batches and the earlier batch has a recent receipt') do
  evict_batches_with_mixed_receipt_ages
end

When('the upgraded service retries eviction after an archive object changes and publishes a new batch') do
  evict_past_legacy_verification_failure
end

When('one batch is evicted while the other is waiting to publish') do
  query_with_local_sibling_batch
end

When('the client searches the same volume after one matching evicted archive object disappears') do
  query_after_archive_loss
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
  expect(page.search_scope).to eq(:LOG_SEARCH_SCOPE_ALL_SOURCES)
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

Then('the Logs results should show a coverage notice only for the local search') do
  expect(@archive_scope_fragment.code).to eq(200)
  expect(@archive_scope_fragment).to label_log_coverage('Results cover logs on this database volume and in the archive.', hidden: true)
  expect(@local_scope_fragment.code).to eq(200)
  expect(@local_scope_fragment).to label_log_coverage('Results cover only logs on this database volume.', empty: true)
end

Then('the log query should report unavailable history') do
  expect(@response.code).to eq(503)
end

Then('the Logs page should show local-only coverage across the rendered pages') do
  expect(@archive_outage_view.code).to eq(503)
  expect(@local_fallback_view.code).to eq(200)
  expect(@local_fallback_view.body).to include('Results cover only logs on this database volume.')
  [@local_logs_view, @local_logs_next_view].each_with_index do |page, index|
    expect(page.code).to eq(200)
    expect(page.body).to include('Results cover only logs on this database volume.')
    expect(page).to show_selected_logs(@query_service, @expected_query_records[index, 1], @query_receipt_windows)
  end
end

Then('the query client should receive local-only results across pages') do
  expect(@local_logs_page.search_scope).to eq(:LOG_SEARCH_SCOPE_CURRENT_VOLUME)
  expect(@local_logs_next_page.search_scope).to eq(:LOG_SEARCH_SCOPE_CURRENT_VOLUME)
  results = @local_logs_page.logs.to_a + @local_logs_next_page.logs.to_a
  expect(results).to have_queried_logs([@request], @expected_query_records.take(2), @query_receipt_windows)
  expect(@changed_scope_response.code).to eq(400)
  expect(@invalid_scope_response.code).to eq(400)
  expect(@oversized_token_response.code).to eq(400)
end

Then('submitting the rendered form should keep the search local-only') do
  expect(@local_form_view.code).to eq(200)
  expect(@local_form_view).to label_log_coverage('Results cover only logs on this database volume.')
  expect(@local_form_view).to show_selected_logs(@query_service, @expected_query_records.take(1), @query_receipt_windows)
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

Then('the metrics endpoint should omit the legacy publication timestamp') do
  expect(@legacy_archive_metrics).to have_archive_backlog('pending_records' => 0)
  expect(@legacy_archive_metrics).not_to match(/^einblick_log_archive_last_publication_timestamp_seconds(?:\{| )/)
end

Then('the metrics endpoint should report the new publication timestamp') do
  published_after_upgrade = be_between(@upgraded_publication_window.begin, @upgraded_publication_window.end)
  expect(@upgraded_archive_metrics).to have_archive_backlog('last_publication_timestamp_seconds' => published_after_upgrade)
end

Then('eviction should complete the healthy batch before retrying the blocked one') do
  expect(@eviction_retry_diagnostics).to complete_archive_batch_before_retry(
    'local log archive eviction', @evicted_batch_id, @retained_batch_id
  )
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

Then('the local-only search should return its records while the archive read is still held') do
  expect(@archive_read_remained_held).to be(true)
  expect(@local_stall_response.code).to eq(200)
  page = Einblick::V1::ListLogsResponse.decode_json(@local_stall_response.body)
  expect(page.search_scope).to eq(:LOG_SEARCH_SCOPE_CURRENT_VOLUME)
  expect(page.logs).to have_queried_logs([@local_stall_request], @local_stall_records, @local_stall_receipts)
end

Then('the queued search should end without listing the archive') do
  # gRPC can reset the stream as the client deadline expires.
  expect(@queued_archive_response).to be_a(GRPC::DeadlineExceeded).or be_a(GRPC::Cancelled)
  expect(@listings_while_archive_query_drained).to eq(0)
end
