# frozen_string_literal: true

Given('typed logs spanning UTC midnight and using both timestamp fallbacks') do
  @archive_request = archive_timestamp_fixture
end

Given('an accepted-size log body larger than the Parquet batch target') do
  @archive_request = large_archive_fixture
end

Given('three same-day logs with large {string} that fit the batch target only two at a time') do |content|
  @archive_request = content == 'bodies' ? same_day_archive_fixture : shared_archive_context_fixture
end

Given('a log export for an earlier UTC day') do
  prepare_archive_storage
  @archive_request = representative_export('logs')
end

Given('an archive workspace with a publicly accessible export directory') do
  prepare_public_archive_directory
end

Given('an acknowledged log export staged in Parquet') do
  prepare_archive_storage
  @archive_request = representative_export('logs')
  stage_log_archive(@archive_request, 1)
  @first_archive_path = archive_files.fetch(0)
  @first_archive_checksum = @archive_file_checksums.fetch(@first_archive_path)
end

Given('an acknowledged export with {string} staging') do |state|
  prepare_archive_storage
  @archive_request = representative_export('logs')
  prepare_archive_recovery(state)
end

When('the service stages the acknowledged logs') do
  prepare_archive_storage
  stage_log_archive(@archive_request, 4)
end

When('the service stages that log export') do
  prepare_archive_storage
  stage_log_archive(@archive_request, 2)
end

When('the logs arrive twice with the same worker running and the first batch already staged') do
  stage_late_log_archive
end

When('the service starts with local archival enabled and the workspace is {string}') do |state|
  start_without_archive_directory(state)
end

When('the service accepts that export while the destination day is unwritable and write access returns') do
  retry_archive_publication
end

When('the service accepts that export with a replacement workspace and the original workspace returns') do
  stage_after_workspace_returns
end

When('another export is accepted and the archive worker restarts') do
  recover_before_staging_new_logs
end

When('the service restarts with an unreadable staged file and receives another log export') do
  export_during_archive_recovery
end

When('the service restarts with writable staging') do
  recover_log_archive
end

When('the service starts with local archival enabled') do
  inspect_archive_directory_at_startup
end

Then('the Parquet files should preserve the complete log export and exact timestamps') do
  expect(@archive_rows).to have_stored_log_export(@archive_request)
  expect(@archive_rows).to have_log_times(@export_started_ns, @archive_inspected_ns)
end

Then('each Parquet file should contain records for its UTC event day') do
  expect(@archive_partitions).to contain_partitioned_log_days('1970-01-01', '1970-01-02', '2554-07-21', archive_receipt_day)
end

Then('the acknowledged logs should remain in DuckDB') do
  expect(@stored_archive_logs).to have_stored_log_export(@archive_request)
  expect(@stored_archive_logs).to eq(@archive_rows)
end

Then('the larger row should have its own batch and retain its original content') do
  expect(@archive_members.map(&:last).tally.values).to contain_exactly(1, 1)
  expect(@archive_rows).to have_stored_log_export(@archive_request)
end

Then('one Parquet batch should contain two logs and the other should contain one') do
  expect(@archive_partitions.values.map(&:size)).to contain_exactly(2, 1)
  expect(@archive_members.map(&:last).tally.values).to contain_exactly(2, 1)
  expect(@archive_rows).to have_stored_log_export(@archive_request)
end

Then('the export directory should be accessible only to the service user') do
  expect(@archive_directory_mode).to eq(0o700)
end

Then('the UTC day should have two distinct complete batches') do
  expect(@archive_partitions).to contain_partitioned_log_days(archive_event_day, archive_event_day)
  expect(@archive_batches.map(&:first).uniq.size).to eq(2)
  expect(@archive_members.map(&:last).tally.values).to contain_exactly(2, 2)
  expect(@archive_rows).to have_stored_log_export(@archive_request, 2)
end

Then('the first completed Parquet file should be unchanged') do
  expect(@archive_file_checksums.fetch(@first_archive_path)).to eq(@first_archive_checksum)
end

Then('the service should defer further staging until read access is restored') do
  expect(@archive_file_count_before_restore).to eq(1)
  expect(@archive_completed_before_restore).to be false
end

Then('the newly accepted logs should be queryable during recovery') do
  expect(@archive_query_response.code).to eq(200)
  page = Einblick::V1::ListLogsResponse.decode_json(@archive_query_response.body)
  expect(page.logs.map(&:record)).to match_array(log_query_records(@archive_request) * 2)
end

Then('each Parquet file should match its durable batch') do
  expect(@archive_file_members).to match_durable_archive_batches(
    @archive_batches, @archive_members, @archive_file_checksums, Einblick::Archive::World::WORKSPACE
  )
end

Then('startup should fail without creating an export directory') do
  expect(@startup_status).not_to be_success, @startup_output
  expect(@startup_output).to include('log archive workspace')
  expect(File.exist?(Einblick::Archive::World::ARCHIVE_DIRECTORY)).to be false
end

Then('the failed publication should leave no temporary or completed files') do
  expect(@failed_publication_files).to be_empty
end

Then('the retry should complete the original batch') do
  expect(@archive_batches.map(&:first)).to eq([@failed_publication_batch_id])
end

Then('the original export should be staged without another request') do
  expect(@archive_batches.size).to eq(1)
  expect(@archive_rows).to have_stored_log_export(@archive_request)
end

Then('the replacement workspace should receive no archive files') do
  expect(@replacement_archive_contents).to eq(['v1'])
  expect(@replacement_archive_version_contents).to be_empty
end

Then('the interrupted batch should complete before the new batch') do
  pending_id = @original_archive_batches.fetch(0).fetch(0)
  expect(@completed_archive_ids).to eq([pending_id, (@archive_batches.map(&:first) - [pending_id]).fetch(0)])
  expect(@archive_members.select { |_id, batch| batch == pending_id }).to eq(@original_archive_members)
end

Then('the original batch membership and content identity should be preserved') do
  expect(@archive_batches.map { |batch| batch.take(3) }).to eq(@original_archive_batches.map { |batch| batch.take(3) })
  expect(@archive_members).to eq(@original_archive_members)
end

Then('only a verified complete Parquet file should remain for the batch') do
  expect(@archive_batches.size).to eq(1)
  expect(@archive_checksums).to eq(@archive_batches.map(&:last))
  expect(@archive_partial_exists).to be false
  expect(@archive_rows).to have_stored_log_export(@archive_request)
end
