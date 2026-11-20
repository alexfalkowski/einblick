# frozen_string_literal: true

RSpec.configure do |config|
  config.wait_timeout = 3
end

RSpec::Matchers.define :have_stored_log_export do |request, copies = 1|
  match do |rows|
    @expected = request.resource_logs.flat_map do |resource|
      resource_header = resource.class.new(resource: resource.resource, schema_url: resource.schema_url)
      resource.scope_logs.flat_map do |scope|
        scope_header = scope.class.new(scope: scope.scope, schema_url: scope.schema_url)
        scope.log_records.map { |record| [resource_header, scope_header, record] }
      end
    end * copies
    @actual = rows.map do |resource, scope, record, *_timestamps|
      [Opentelemetry::Proto::Logs::V1::ResourceLogs.decode_json(resource),
       Opentelemetry::Proto::Logs::V1::ScopeLogs.decode_json(scope),
       Opentelemetry::Proto::Logs::V1::LogRecord.decode_json(record)]
    end
    @actual == @expected
  end

  failure_message do
    "expected #{@expected.size} complete stored log records, got #{@actual.size}; content differs: #{@actual != @expected}"
  end
end

RSpec::Matchers.define :have_log_times do |start_ns, end_ns|
  match do |rows|
    rows.all? do |row|
      timestamp, observed, received, selected = row.drop(3)
      record = Opentelemetry::Proto::Logs::V1::LogRecord.decode_json(row[2])
      timestamp == record.time_unix_nano && observed == record.observed_time_unix_nano &&
        received.between?(start_ns, end_ns) && selected == (timestamp.nonzero? || observed.nonzero? || received)
    end
  end

  failure_message do
    'expected original unsigned nanoseconds, separate receipt time, and Timestamp/ObservedTimestamp/receipt selection'
  end
end

RSpec::Matchers.define :have_log_storage_growth do |request, before|
  match do |after|
    scopes = request.resource_logs.flat_map(&:scope_logs).select { |scope| scope.log_records.any? }
    @expected = {
      'logs' => scopes.sum { |scope| scope.log_records.size },
      'log_scopes' => scopes.size,
      'log_resources' => request.resource_logs.count { |resource| resource.scope_logs.any? { |scope| scope.log_records.any? } }
    }
    @actual = before.to_h { |table, rows| [table, after.fetch(table).size - rows.size] }
    @actual == @expected
  end

  failure_message do
    "expected stored row growth #{@expected}, got #{@actual}; empty containers must not allocate context"
  end
end

RSpec::Matchers.define :exclude_log_payload do |request|
  match do |output|
    attributes = request.resource_logs.first.scope_logs.first.log_records.first.attributes
    marker = attributes.find { |attribute| attribute.key == 'request.id' }.value.string_value
    !marker.empty? && !output.include?(marker)
  end

  failure_message do
    'expected all export output to exclude the unique log payload marker, including component=logs diagnostics'
  end
end

RSpec::Matchers.define :have_log_commit do |request|
  match do |output|
    commits = output.lines.filter_map do |line|
      fields = line.scan(/(?:\A|\s)([\w.]+)=("(?:\\.|[^"\\])*"|\S+)/).to_h
      fields if fields['component'] == 'logs' && fields['msg'] == '"log export committed"'
    end
    next commits.any? unless request

    @expected = request.resource_logs.sum { |resource| resource.scope_logs.sum { |scope| scope.log_records.size } }
    commits.any? { |fields| fields['records'] == @expected.to_s }
  end

  failure_message do
    "expected a component=logs committed diagnostic with records=#{@expected}"
  end

  failure_message_when_negated do
    'expected no component=logs committed diagnostic for the rejected export'
  end
end

RSpec::Matchers.define :have_duckdb_metric do |name|
  match do |output|
    output.lines.any? do |line|
      sample = line.match(/\A#{Regexp.escape(name)}\{([^}]*)\}\s/)
      sample && sample[1].split(',').include?('db_system_name="duckdb"')
    end
  end

  failure_message do
    "expected a #{name} sample with db_system_name=duckdb"
  end
end

RSpec::Matchers.define :have_otlp_export do |signal, request|
  match do |output|
    receipts = output.lines.filter_map do |line|
      fields = line.scan(/(?:\A|\s)([\w.]+)=("(?:\\.|[^"\\])*"|\S+)/).to_h
      fields if fields['signal'] == signal
    end
    next receipts.any? unless request
    next false unless receipts.one?
    next false if receipts.first.key?('payload')

    # The complete request is the message; slog leaves the empty {} unquoted.
    payload = receipts.first['msg']
    next false unless payload

    payload = JSON.parse(payload) if payload.start_with?('"')
    actual = request.class.decode_json(payload)
    actual == request
  end

  failure_message do
    if request
      "expected exactly one OTLP #{signal} message matching the exported request, without a payload field"
    else
      "expected an OTLP #{signal} receipt"
    end
  end
end
