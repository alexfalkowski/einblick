# frozen_string_literal: true

When('the server reopens an up-to-date schema') do
  reopen_current_schema
end

When('the server attempts to open a newer migration history') do
  attempt_future_migration
end

When('a schema conflict interrupts migration and is repaired') do
  recover_conflicting_migration
end

Then('migration history should record schema version {int}') do |version|
  expect(@migration_history).to eq([[0], [version]].uniq)
end

Then('migration history and stored records should be unchanged') do
  expect(@schema_data_after).to eq(@schema_data_before)
  expect(@migration_history_after).to eq(@migration_history_before)
end

Then('startup should reject the newer migration history without changing storage') do
  expect(@startup_status).not_to be_success, @startup_output
  expect(@startup_output).to include('migrate: unsupported storage schema version 2')
  expect(@schema_data_after).to eq(@schema_data_before)
  expect(@migration_history_after).to eq(@migration_history_before)
end

Then("startup should fail without committing the migration's schema changes") do
  expect(@startup_status).not_to be_success, @startup_output
  expect(@startup_output).to include('migration', 'logs')
  expect(@failed_schema_tables).to be_empty
  expect(@failed_schema_sequences).to be_empty
end

Then('migration history should record schema version {int} at the failure') do |version|
  expect(@failed_migration_history).to eq([[version]])
end

Then('the conflicting schema and unrelated data should remain intact') do
  expect(@failed_schema_conflict).to eq([['preserved']])
  expect(@migration_probe).to eq([['preserved']])
end

Then('the server should accept and persist a new log export') do
  expect(@response).to be_a(Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceResponse)
  expect(@response.partial_success).to be_nil
  expect(@stored_logs).to have_stored_log_export(@request)
end
