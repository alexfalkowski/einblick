# frozen_string_literal: true

module Einblick
  module Archive
    # Exercises the daily cutoff and late arrivals through OTLP, Floci and log search.
    module World
      DAY_NANOSECONDS = 86_400_000_000_000

      def prepare_daily_logs
        prepare_archive_storage
        midnight = daily_midnight
        @daily_cutoff = midnight - DAY_NANOSECONDS
        service = "daily-archive-#{SecureRandom.uuid}"
        @query = { 'service' => service, 'start_time' => query_time(@daily_cutoff - (2 * DAY_NANOSECONDS)),
                   'end_time' => query_time(midnight + DAY_NANOSECONDS) }
        acknowledge_archive_logs(daily_archive_fixture(service))
        finish_daily_receipts(except: @late_event)
      end

      def daily_midnight
        today = Time.now.utc
        Time.utc(today.year, today.month, today.day).to_i * 1_000_000_000
      end

      def daily_archive_fixture(service)
        request = query_fixture('log_queries', service: service)
        request.resource_logs.replace([request.resource_logs.first])
        records = request.resource_logs.first.scope_logs.first.log_records
        records.replace([records.first.dup, *records])
        @daily_records = records.to_a
        set_daily_event_times
        request
      end

      def large_archive_resource_fixture(count, context_bytes: Random.new(1).bytes(50_000))
        request = representative_export('logs')
        resource = request.resource_logs.first
        add_archive_context_attribute(resource.resource, context_bytes)
        records = resource.scope_logs.first.log_records
        records.replace(Array.new(count) do |index|
          records.first.dup.tap { |record| record.time_unix_nano += index }
        end)
        request
      end

      def prepare_large_daily_logs(count)
        prepare_archive_storage
        # Eight rows with this base64-encoded resource exceed one MiB.
        @archive_request = large_archive_resource_fixture(count, context_bytes: 'x'.b * 100_000)
        commit_archive_fixture(@archive_request)
      end

      def publish_large_daily_logs
        @archive_offset = File.size('reports/server.log')
        with_floci do
          with_server_profile('history') { wait_for_daily_evictions(1) }
          @large_daily_archive_keys = @floci.keys
          inspect_large_daily_archive(@floci.download(@large_daily_archive_keys.fetch(0)))
        end
        inspect_eviction
      end

      def set_daily_event_times
        offsets = [-2 * DAY_NANOSECONDS, (-2 * DAY_NANOSECONDS) + 1, -DAY_NANOSECONDS, -2, -1, -3, 0, DAY_NANOSECONDS]
        @daily_records.zip(offsets).each { |record, offset| record.time_unix_nano = @daily_cutoff + offset }
        @late_event = @daily_records.fetch(5).time_unix_nano
      end

      def publish_daily_logs
        @archive_offset = File.size('reports/server.log')
        with_floci do
          with_server_profile('history') { wait_for_daily_evictions(2) }
          @daily_events_before_supplement = daily_local_event_times
          finish_daily_receipts
          with_server_profile('history') { collect_daily_archive_pages }
          @daily_events_after_supplement = daily_local_event_times
        end
      end

      def daily_local_event_times
        with_log_database { |connection| connection.query('SELECT event_timestamp_ns FROM logs').to_a.flatten }
      end

      def collect_daily_archive_pages
        wait_for_daily_evictions(3)
        @query_record_count = @daily_records.size
        keys = @floci.keys
        newer_day = File.dirname(keys.max)
        page_size = @query_record_count - 1
        listings = @floci.archive_listings
        first = next_log_query_page('', page_size: page_size)
        @daily_initial_listings = @floci.archive_listings - listings
        @floci.unreadable_archives = keys.select { |key| File.dirname(key) == newer_day }
        collect_log_pages(first, page_size: page_size)
      end

      def finish_daily_receipts(except: 0)
        with_log_database do |connection|
          connection.query('UPDATE logs SET received_timestamp_ns = ? WHERE event_timestamp_ns <> ?', @daily_cutoff, except)
        end
      end

      def wait_for_daily_evictions(count)
        wait(timeout: 10).for { @floci.keys.size }.to eq(count)
        wait_for_archive_evictions(*@floci.keys)
      end
    end
  end
end
