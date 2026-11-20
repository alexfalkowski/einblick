# frozen_string_literal: true

Given('a log export containing {int} records') do |count|
  request = representative_export('logs')
  records = request.resource_logs.first.scope_logs.first.log_records
  record = Opentelemetry::Proto::Logs::V1::LogRecord.new(body: { string_value: SecureRandom.uuid })
  records.clear
  count.times { records << record }
  prepare_export('logs', request)
end

Given('a log export with a {int} byte body') do |size|
  request = representative_export('logs')
  request.resource_logs.first.scope_logs.first.log_records.first.body.string_value = 'x' * size
  prepare_export('logs', request)
end

Given('a log export with timestamp {int} and observed timestamp {int}') do |timestamp, observed|
  prepare_log_times(timestamp, observed)
end

Given('a log export with every supported body type and optional context') do
  prepare_log_bodies
end

Given('a log export with {string} and no records') do |context|
  prepare_record_free_log_export(context)
end

Given('acknowledged local logs') do
  prepare_acknowledged_log_export
  expect(@response).to be_a(Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceResponse)
  expect(@response.partial_success).to be_nil
  expect(@stored_logs).to have_stored_log_export(@request)
end

Given('a log export spanning multiple resources with a conflicting later record') do
  prepare_conflicting_log_export
end

Given('a multi-resource log export was rejected by a later storage write') do
  prepare_conflicting_log_export
  export_with_log_write_conflict
  expect(@response).to be_a(GRPC::BadStatus)
  expect(@response.code).to eq(GRPC::Core::StatusCodes::UNAVAILABLE)
  expect(@storage_snapshot_after).to eq(@storage_snapshot_before)
end

Given('a malformed log export has been rejected') do
  export_malformed_logs
  expect(@response).to be_a(GRPC::BadStatus)
  expect(@response.code).to eq(GRPC::Core::StatusCodes::INTERNAL)
end

Given('a log export was rejected while local storage was unwritable') do
  prepare_rejected_log_export
  expect(@response).to be_a(GRPC::BadStatus)
  expect(@response.code).to eq(GRPC::Core::StatusCodes::UNAVAILABLE)
end

Given('a local database with unrelated data and no log tables') do
  prepare_log_database
end

When('the client exports the same logs twice') do
  export_duplicate_logs
end

When('the client exports logs without a writable local disk') do
  export_without_writable_disk
end

When('the client exports logs with a later storage write rejected') do
  export_with_log_write_conflict
end

When('the server initializes a database without log tables') do
  initialize_log_database
end

Then('the complete log export should survive a/an {string} restart') do |mode|
  reopen_log_storage(mode)
  expect(@stored_logs).to have_stored_log_export(@request)
end

Then('both log exports should succeed without partial success') do
  expect(@responses).to all(be_a(Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceResponse))
  expect(@responses.map(&:partial_success)).to all(be_nil)
end

Then('the stored logs should contain {int} copies of the complete export') do |copies|
  reopen_log_storage('graceful')
  expect(@stored_logs).to have_stored_log_export(@request, copies)
end

Then('stored log timestamps should follow the log time policy') do
  expect(@stored_logs).not_to be_empty
  expect(@stored_logs).to have_log_times(@export_started_ns, @storage_inspected_ns)
end

Then('no logs should have been stored for this export') do
  reopen_log_storage('graceful')
  expect(@stored_logs).to be_empty
end

Then('existing local records and context should be unchanged') do
  expect(@storage_snapshot_after).to eq(@storage_snapshot_before)
end

Then('previously acknowledged records and context should be unchanged') do
  expect(@storage_snapshot_after.fetch('logs')).to include(*@storage_snapshot_before.fetch('logs'))
  expect(@storage_snapshot_after.fetch('log_scopes')).to include(*@storage_snapshot_before.fetch('log_scopes'))
  expect(@storage_snapshot_after.fetch('log_resources')).to include(*@storage_snapshot_before.fetch('log_resources'))
end

Then('only resource and scope context for stored records should be allocated') do
  expect(@storage_snapshot_after).to have_log_storage_growth(@request, @storage_snapshot_before)
end

Then('log diagnostics should not contain the export payload') do
  expect(File.read('reports/server.log', nil, @receipt_offset)).to exclude_log_payload(@request)
end

Then('local diagnostics should report the exact committed log count') do
  expect(File.read('reports/server.log', nil, @receipt_offset)).to have_log_commit(@request)
end

Then('local diagnostics should identify a log commit failure') do
  expect(@failure_output).to include('log export failed', 'logs: commit')
  expect(@failure_output).not_to have_log_commit
end

Then('log failure diagnostics should not contain the export payload') do
  expect(@failure_output).to exclude_log_payload(@request)
end

Then('log storage should be initialized without changing unrelated data') do
  expect(@migration_result).to eq([[1, 'preserved']])
end
