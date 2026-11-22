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

When('the client continues the search during publication overlap and after local eviction') do
  continue_across_eviction
end

When('the archive is published and the client searches from a fresh database volume') do
  query_fresh_archive
end

When('the archive is published and the client searches during an object store outage') do
  query_fresh_archive(failure: true)
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

Then('the log query should report unavailable history') do
  expect(@response.code).to eq(503)
end

Then('the search should have returned both copies of the matching logs before the loss') do
  expect(@logs_before_archive_loss.size).to eq(2 * @expected_query_records.size)
  expect(@available_archive_keys.size).to eq(1)
end

Then('the cancelled archive query should return gRPC cancelled') do
  expect(@grpc_response).to be_a(GRPC::Cancelled)
end

Then('the queued search should end without listing the archive') do
  # gRPC can reset the stream as the client deadline expires.
  expect(@queued_archive_response).to be_a(GRPC::DeadlineExceeded).or be_a(GRPC::Cancelled)
  expect(@listings_while_archive_query_drained).to eq(0)
end
