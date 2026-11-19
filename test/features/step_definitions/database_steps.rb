# frozen_string_literal: true

When('the server starts with an unusable database file') do
  attempt_database_start('unusable_database.yaml')
end

When('the server starts with configuration {string}') do |config|
  attempt_database_start(config)
end

Then('startup should fail because the database file cannot be opened') do
  expect(@startup_status).to be_a(Process::Status), @startup_output
  expect(@startup_status).not_to be_success, @startup_output
  expect(@startup_output).to include('IO Error:', '.config', 'directory'), @startup_output
end

Then('startup should fail database path validation with {string}') do |rule|
  expect(@startup_status).to be_a(Process::Status), @startup_output
  expect(@startup_status).not_to be_success, @startup_output
  expect(@startup_output).to include('Config.DuckDB.Path', "failed on the '#{rule}' tag"), @startup_output
end
