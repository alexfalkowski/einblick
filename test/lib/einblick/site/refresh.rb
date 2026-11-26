# frozen_string_literal: true

module Einblick
  module Site
    ARRIVING_MESSAGE = 'newly arrived log'
    PAGED_ARRIVAL_MESSAGE = 'first new request'

    # Repeats searches after storage acknowledges a newly arrived log.
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

      def refresh_paged_search
        acknowledge_arriving_log(PAGED_ARRIVAL_MESSAGE)
        refresh_displayed_search(@native_pages.last, 'full', reload: true)
      end

      private

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
