# frozen_string_literal: true

module Einblick
  module Site
    ARRIVING_MESSAGE = 'newly arrived log'
    PAGED_ARRIVAL_MESSAGE = 'first new request'

    # Exercises repeat searches, edits and invalid view requests.
    module World
      def repeat_search_after_log_arrives(range, layout, reload: false)
        @arrival_filters = @query.slice('service').merge('text' => ARRIVING_MESSAGE)
        page = site_client.open("/logs?#{URI.encode_www_form(@arrival_filters)}", 'en')
        @search_before_arrival = range == 'default' ? page : choose_time_range(range, page: page, layout: 'full')
        acknowledge_arriving_log

        refresh_displayed_search(@search_before_arrival, layout, reload: reload)
      end

      def clear_message_then_refresh
        @cleared_filters = @query.slice('service').merge('page_size' => '1')
        page = site_client.open("/logs?#{URI.encode_www_form(@cleared_filters.merge('text' => ARRIVING_MESSAGE))}", 'en')
        @empty_message_search = choose_time_range('1 hour', page: page, layout: 'full')
        acknowledge_arriving_log
        @cleared_search = site_client.submit_log_form(@empty_message_search, 'en', submitter: 'Clear search', layout: 'full')
        refresh_displayed_search(@cleared_search, 'full')
      end

      def clear_message_with_edited_dates(range)
        fixed = range == 'fixed'
        @empty_message_search = if fixed
                                  investigate_logs('full', 'en', 'custom' => '1', 'text' => MISSING_TERM)
                                else
                                  open_rolling_message_search
                                end
        edits = { 'custom' => fixed ? '1' : 'picker', 'start_utc' => '2000-01-01T00:00:00', 'end_utc' => '' }
        @response = site_client.submit_log_form(@empty_message_search, 'en', submitter: 'Clear search', layout: 'full', edits: edits)
      end

      def open_picker_only_bookmark
        dates = { start_utc: '2026-11-19T11:04', end_utc: '2026-11-19T11:06' }
        @response = site_client.open("/logs?#{URI.encode_www_form(dates)}", 'en')
      end

      def submit_picker_dates(start_utc, end_utc)
        investigate_logs('full', 'en', 'custom' => 'picker', 'start_utc' => start_utc, 'end_utc' => end_utc)
      end

      def load_activity_outside_a_valid_search
        @log_activity = site_client.open('/logs/activity?start_time=invalid', 'en')
      end

      def load_activity_for_clipped_range
        bounds = { start_time: '2026-11-19T10:30:00Z', end_time: '2026-11-19T11:00:42.123456789Z' }
        @log_activity = site_client.open("/logs/activity?#{URI.encode_www_form(bounds)}", 'en')
      end

      def prepare_activity_boundary_logs
        prepare_searchable_logs do |records|
          before, at = records.values_at(2, 3)
          boundary = at.time_unix_nano.div(1_000_000_000) * 1_000_000_000
          before.time_unix_nano = boundary - 1
          at.time_unix_nano = boundary
          before.body.string_value = 'just before the bucket boundary'
          at.body.string_value = 'on the bucket boundary'
        end
      end

      def refresh_paged_search
        acknowledge_arriving_log(PAGED_ARRIVAL_MESSAGE)
        refresh_displayed_search(@native_pages.last, 'full', reload: true)
      end

      private

      def open_rolling_message_search
        acknowledge_arriving_log
        filters = @query.slice('service').merge('text' => MISSING_TERM, 'window' => '15m')
        site_client.open("/logs?#{URI.encode_www_form(filters)}", 'en')
      end

      def refresh_displayed_search(page, layout, reload: false)
        @search_layout = layout
        started = Time.now.utc
        @response = if reload
                      site_client.open_log_query(page, 'en')
                    else
                      site_client.submit_log_form(page, 'en', submitter: 'Search', layout: layout)
                    end
        @search_time = started..Time.now.utc
      end

      def acknowledge_arriving_log(message = ARRIVING_MESSAGE)
        request = query_fixture('log_query_times')
        records = request.resource_logs.first.scope_logs.first.log_records
        record = records.first
        record.time_unix_nano = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
        record.body.string_value = message
        record.trace_id = [FIXTURE_TRACE_ID].pack('H*')
        records.replace([record])
        acknowledge_query_export(request)
      end
    end
  end
end
