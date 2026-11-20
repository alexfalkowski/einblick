# frozen_string_literal: true

module Einblick
  module Logs
    # Concurrent clients and metrics exercise the configured work limit.
    module World
      def capture_concurrent_query_timeouts
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        clients = Array.new(4) { Thread.new { HTTP.new('http://localhost:11000').list(@heavy_query) } }
        sample_query_work(clients)
        @concurrent_query_responses = clients.map(&:value)
        @timeout_response = @concurrent_query_responses.first
        @query_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      ensure
        clients&.each(&:join)
      end

      def sample_query_work(clients)
        @query_metrics = []
        while clients.any?(&:alive?)
          @query_metrics << Nonnative.observability.metrics.body
          sleep 0.01
        end
      end

      def wait_for_log_query_limit(limit)
        wait_for { [@caller_query_metrics = Nonnative.observability.metrics.body] }.to have_active_log_query_limit(limit)
      end
    end
  end
end
