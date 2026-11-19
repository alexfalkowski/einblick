# frozen_string_literal: true

When('the system requests the {string} with HTTP') do |name|
  opts = {
    headers: { request_id: SecureRandom.uuid },
    read_timeout: 10, open_timeout: 10
  }

  @response = Nonnative.observability.send(name, opts)
end

Then('the system should respond with a healthy status with HTTP') do
  expect(@response.code).to eq(200)
  expect(@response.body.strip).to eq('SERVING')
end

Then('the system should respond with metrics') do
  expect(@response.code).to eq(200)
  expect(@response.body).to include('go_info')
end

Then('the system should respond with DuckDB metrics') do
  expect(@response.body).to have_duckdb_metric('einblick_db_sql_connection_open')
  expect(@response.body).to have_duckdb_metric('einblick_db_client_operation_duration_seconds_count')
end
