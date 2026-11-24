# frozen_string_literal: true

module Einblick
  module Archive
    # Investigates logs while archive access is interrupted and then restored.
    module World
      def search_history_during_archive_outage
        age_pending_archive_receipts
        site = Einblick::Site::HTTP.new('http://localhost:11000')
        with_floci do
          @floci.pause_access
          with_server_profile('publication') { investigate_archive_outage(site) }
        end
      end

      def search_after_removing_archive_configuration
        with_floci do
          publish_searchable_logs
          with_archive_eviction
          site = Einblick::Site::HTTP.new('http://localhost:11000')
          capture_unavailable_history(site)
          @recent_logs_view = site.open('/logs', 'en')
        end
      end

      def search_recent_logs_during_archive_outage
        site = Einblick::Site::HTTP.new('http://localhost:11000')
        search = @query.except('start_time', 'end_time').merge('window' => '24h')
        with_floci do
          @floci.pause_access
          with_server_profile('publication') do
            wait_for_utc_query_window
            @recent_logs_view = site.open("/logs?#{URI.encode_www_form(search)}", 'en')
            read_recent_log_pages
          end
        end
      end

      private

      def wait_for_utc_query_window
        # Keep the browser request, the API pages and their deadlines on the same UTC day.
        now = Time.now.utc
        midnight = Time.utc(now.year, now.month, now.day) + 86_400
        remaining = midnight - now
        sleep(remaining) if remaining <= 120
      end

      def move_logs_to_recent_window(request)
        start = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond) - 1_000_000_000
        shift = start - Einblick::Logs::World::QUERY_TIME
        log_query_records(request).each { |record| record.time_unix_nano += shift }
        { 'start_time' => query_time(start), 'end_time' => query_time(start + 10) }
      end

      def investigate_archive_outage(site)
        path = capture_unavailable_history(site)
        capture_pending_archive_backlog
        capture_archive_backlog_recovery
        @recovered_history_view = site.open(path, 'en')
      end

      def capture_unavailable_history(site)
        search = @query.merge('page_size' => 1)
        path = "/logs?#{URI.encode_www_form(search)}"
        @archive_outage_view = site.open(path, 'en')
        @archive_outage_fragment = site.submit('/logs', search, 'en')
        @archive_outage_api_response = query_logs
        path
      end

      def read_recent_log_pages
        now = Time.now.utc
        bounds = { 'start_time' => (now - 86_400).iso8601(9), 'end_time' => now.iso8601(9) }
        @recent_log_page = next_log_query_page('', page_size: 1, **bounds)
        token = @recent_log_page.next_page_token
        @recent_log_next_page = next_log_query_page(token, page_size: 1, **bounds)
        @oversized_token_response = query_logs(bounds.merge('page_size' => 1, 'page_token' => padded_page_token(token)))
      end

      def padded_page_token(token)
        json = Base64.urlsafe_decode64(token)
        Base64.urlsafe_encode64(json + (' ' * json.bytesize), padding: false)
      end
    end
  end
end
