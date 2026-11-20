# frozen_string_literal: true

module Einblick
  module Logs
    # Time fixtures retain the same headers and typed records as ordinary queries.
    module World
      def prepare_all_service_query
        request = query_fixture('log_queries')
        start = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
        records = log_query_records(request)
        records.each { |record| record.time_unix_nano += start - QUERY_TIME }
        acknowledge_query_export(request)
        @query = { 'start_time' => query_time(start), 'end_time' => query_time(start + 10) }
        @expected_query_records = [5, 9, 8, 4, 7, 3, 2, 1].map { |index| records[index] }
      end

      def query_full_precision_logs
        request = timed_query_export([(2**64) - 1, (2**64) - 2])
        acknowledge_query_export(request)
        @query = { 'start_time' => query_time((2**64) - 2), 'end_time' => query_time(2**64), 'service' => @query_service }
        query_logs('page_size' => 1)
        first_page = Einblick::V1::ListLogsResponse.decode_json(@response.body)
        collect_log_pages(first_page, page_size: 1)
      end

      def query_receipt_time_logs
        request = timed_query_export([0, 0])
        acknowledge_query_export(request)
        @expected_query_records.reverse!
        @query = { 'service' => @query_service, 'start_time' => query_time(@export_started_ns),
                   'end_time' => query_time(Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond) + 1) }
        query_logs
      end

      def timed_query_export(timestamps)
        request = query_fixture('log_query_times')
        records = request.resource_logs.first.scope_logs.first.log_records
        records.zip(timestamps).each { |record, timestamp| record.time_unix_nano = timestamp }
        @expected_query_records = records.to_a
        request
      end
    end
  end
end
