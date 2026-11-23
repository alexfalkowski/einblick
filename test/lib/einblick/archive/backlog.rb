# frozen_string_literal: true

module Einblick
  module Archive
    # Scrapes backlog metrics while publication recovers or a database read times out.
    module World
      BACKLOG_QUERY_WORK = 'reports/backlog-query-work'

      def capture_pending_archive_backlog
        wait_for do
          @archive_metrics_during_outage = Nonnative.observability.metrics.body
        end.to have_archive_backlog('pending_oldest_age_seconds' => be_positive)
      end

      def capture_archive_backlog_recovery
        recovery_started = Time.now.to_i
        @floci.restore
        wait(timeout: 10).for do
          @archive_metrics_after_recovery = Nonnative.observability.metrics.body
        end.to have_archive_backlog('pending_records' => 0)
        @archive_recovery_window = recovery_started..Time.now.to_i
      end

      def capture_failed_backlog_refreshes
        @archive_offset = File.size('reports/server.log')
        @backlog_scrapes = []
        with_server_profile('backlog_timeout') do
          capture_pending_archive_backlog
          FileUtils.touch(BACKLOG_QUERY_WORK)
          wait_for_withdrawn_backlog_gauges
          wait(timeout: 10).for { @backlog_refresh_diagnostics = archive_diagnostics }.to have_backlog_refresh_failures(2)
        end
      ensure
        FileUtils.rm_f(BACKLOG_QUERY_WORK)
      end

      def wait_for_withdrawn_backlog_gauges
        wait(timeout: 10).for { observe_backlog_while_scraping }.to have_backlog_refresh_failures(1)
        wait(timeout: 10).for do
          @metrics_after_backlog_timeout = Nonnative.observability.metrics
        end.to omit_archive_backlog_gauges
      end

      def prepare_backlog_query_work
        FileUtils.rm_f(BACKLOG_QUERY_WORK)
        with_log_database { |connection| connection.query(File.read('fixtures/backlog_query_work.sql')) }
      end

      def observe_backlog_while_scraping
        started = Time.now
        response = Nonnative.observability.metrics
        @backlog_scrapes << [started, Time.now, response]
        archive_diagnostics
      end
    end
  end
end
