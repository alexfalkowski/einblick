# frozen_string_literal: true

module Einblick
  module Site
    # Builds acknowledged OTLP records for the inspector and related-log search.
    module World
      def prepare_markup_log
        prepare_searchable_logs
        @query_service = "#{@query_service}-<b>service</b>"
        @query['service'] = @query_service
        request = query_fixture('log_queries')
        scope = request.resource_logs.first.scope_logs.first
        scope.log_records.replace([log_with_markup(scope.log_records[2])])
        acknowledge_query_export(request)
      end

      def prepare_request_log(protocol, status, duration)
        prepare_searchable_logs do |records|
          records[2].attributes.push(*request_attributes(protocol.downcase, status, duration))
        end
        @query['text'] = 'same-time first'
      end

      def prepare_related_log_search
        prepare_searchable_logs do |records|
          other_message, target, error, newer = records.values_at(1, 2, 3, 5)
          newer.severity_number = :SEVERITY_NUMBER_INFO
          newer.body.string_value = 'newer first request'
          error.trace_id = other_message.trace_id = target.trace_id
          error.body.string_value = 'first error on the same trace'
          other_message.body.string_value = 'another message on the same trace'
        end
      end

      def prepare_recent_filtered_logs
        recent = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond) - 10_000_000_000
        shift = recent - Einblick::Logs::World::QUERY_TIME
        prepare_searchable_logs do |records|
          configure_recent_trace(records)
          records.each { |record| record.time_unix_nano += shift }
        end
        @query.merge!(RELATED_LOG_FILTERS, 'trace_id' => FIXTURE_TRACE_ID)
      end

      def prepare_blank_logs
        prepare_searchable_logs
        @query_service = "#{@query_service}-blank"
        @query['service'] = @query_service
        start = Einblick::Logs::World::QUERY_TIME
        request = timed_query_export([start, start + 1])
        records = log_query_records(request)
        records[0].body.string_value = ''
        records[1].body.string_value = " \t"
        acknowledge_query_export(request)
      end

      def prepare_unsigned_logs
        prepare_searchable_logs
        upper = 2**64
        request = timed_query_export([upper - 1, upper - 2])
        log_query_records(request).first.observed_time_unix_nano = upper - 3
        acknowledge_query_export(request)
        @query.merge!('start_time' => query_time(upper - 2), 'end_time' => query_time(upper))
      end

      def prepare_logs_without_event_time
        prepare_searchable_logs
        request = timed_query_export([0, 0])
        observed_log, receipt_log = @expected_query_records
        observed_log.observed_time_unix_nano = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond) - 2_000_000_000
        observed_log.body.string_value = 'request with an observed timestamp'
        receipt_log.body.string_value = 'request with no original timestamps'
        acknowledge_query_export(request)
        select_logs_without_event_time(observed_log, receipt_log)
      end

      private

      def configure_recent_trace(records)
        older, latest, error, other_message, other_trace = records.values_at(1, 2, 3, 4, 5)
        trace_id = latest.trace_id
        older.trace_id = trace_id
        other_message.severity_number = :SEVERITY_NUMBER_INFO
        other_trace.severity_number = :SEVERITY_NUMBER_INFO
        set_trace_message(error, trace_id, 'first error')
        set_trace_message(other_message, trace_id, 'different message')
        set_trace_message(other_trace, trace_id.reverse, 'first on another trace')
      end

      def set_trace_message(record, trace_id, message)
        record.trace_id = trace_id
        record.body.string_value = message
      end

      def log_with_markup(record)
        record.body.string_value = MARKUP_MESSAGE
        record.attributes.first.value.string_value = '<img src=x>attribute'
        record.attributes.push(*request_attributes('http', '200', '235.055614ms'))
        record.severity_number = 100
        record
      end

      def request_attributes(system, status, duration)
        key_value = Opentelemetry::Proto::Common::V1::KeyValue
        code = system == 'http' ? { int_value: Integer(status) } : { string_value: status }
        [key_value.new(key: 'system', value: { string_value: system }), key_value.new(key: 'code', value: code),
         key_value.new(key: 'duration', value: { string_value: duration })]
      end

      def select_logs_without_event_time(observed_log, receipt_log)
        receipt_end = @query_receipt_windows.fetch(receipt_log).end + 1
        @query.merge!('start_time' => query_time(observed_log.observed_time_unix_nano), 'end_time' => query_time(receipt_end),
                      'text' => 'request with')
        @expected_query_records.reverse!
      end
    end
  end
end
