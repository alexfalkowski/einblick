# frozen_string_literal: true

module Einblick
  module Archive
    # Submits edited Custom ranges using the picker rendered with archive retention.
    module World
      def submit_new_custom_ranges
        with_retention_profile do
          open_retention_picker
          @valid_custom_start = @retention_query_window.begin.floor - 7200
          @valid_custom_search = submit_custom_picker_range(@valid_custom_start)
          @expired_custom_search = submit_aged_custom_range
        end
      end

      private

      def open_retention_picker
        started = Time.now.utc
        bounds = { custom: 1, start_time: (started - 3600).iso8601, end_time: started.iso8601 }
        @retention_search = site_client.open("/logs?#{URI.encode_www_form(bounds)}", 'en')
        @retention_query_window = started..Time.now.utc
      end

      def submit_aged_custom_range
        start = @retention_query_window.end.floor - HISTORY_RETENTION_SECONDS + 1
        wait_until_history_cutoff_passes(start)
        @expired_custom_start = start
        submitted_at = Time.now.utc
        response = submit_custom_picker_range(start, layout: 'partial')
        earliest_cutoff = (submitted_at - HISTORY_RETENTION_SECONDS).floor
        latest_cutoff = (Time.now.utc - HISTORY_RETENTION_SECONDS).floor
        @expired_cutoff_window = earliest_cutoff..latest_cutoff
        response
      end

      def submit_custom_picker_range(start, layout: 'full')
        dates = { 'start_utc' => start.strftime('%FT%T'), 'end_utc' => (start + 3600).strftime('%FT%T') }
        site_client.submit_log_form(@retention_search, 'en', submitter: 'Search', layout:, edits: dates)
      end

      def wait_until_history_cutoff_passes(start)
        cutoff_passes_at = start + HISTORY_RETENTION_SECONDS
        wait_for { Time.now.utc.floor }.to be > cutoff_passes_at
      end
    end
  end
end
