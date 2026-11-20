# frozen_string_literal: true

module Einblick
  module Logs
    # Additional query actions share the established World and process lifecycle.
    module World
      def with_query_profile(profile)
        process = Nonnative.configuration.process_by_name('server')
        original = process.command
        Nonnative.stop
        process.command = -> { ['../einblick', 'server', '-config', "file:.config/#{profile}.yaml"] }
        Nonnative.start
        yield
      ensure
        Nonnative.stop
        process.command = original
        Nonnative.start
      end

      def query_with_expired_budget
        with_query_profile('query_timeout') do
          capture_query_timeout
        end
        query_logs
      end

      def capture_query_timeout
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        query_logs
        @timeout_response = @response
        @query_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      end

      # A disposable view creates native scan work without a large on-disk fixture.
      # The continuation excludes its extra rows, so recovery is exercised in the
      # same process, with the same query slot and configured timeout.
      def prepare_native_query_work
        query_logs('page_size' => 1)
        @heavy_query = @query.merge('page_size' => 1, 'page_token' => Einblick::V1::ListLogsResponse.decode_json(@response.body).next_page_token)
        prepare_first_log_page
        with_log_database { |connection| connection.query(File.read('fixtures/query_work.sql')) }
      end

      def query_with_native_cancellation
        with_query_profile('query_work') do
          capture_concurrent_query_timeouts
          collect_log_pages(@first_log_page)
        end
      end

      # The scenario hook also runs when fixture installation or its restart fails.
      def restore_native_query_work
        with_log_database do |connection|
          source = connection.query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' " \
                                    "AND table_name = 'query_source_logs'").to_a
          next if source.empty?

          connection.query('DROP VIEW IF EXISTS logs; ALTER TABLE query_source_logs RENAME TO logs')
        end
      end

      def query_unavailable_storage(transport = 'http')
        with_log_database { |connection| connection.query('ALTER TABLE logs RENAME TO unavailable_logs') }
        transport == 'grpc' ? query_grpc_logs : query_logs
      ensure
        with_log_database { |connection| connection.query('ALTER TABLE unavailable_logs RENAME TO logs') }
      end

      def query_with_caller_cancellation
        with_query_profile('query_cancellation') do
          cancel_active_grpc_query
          collect_log_pages(@first_log_page)
        end
      end
    end
  end
end
