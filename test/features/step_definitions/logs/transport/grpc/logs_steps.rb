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
