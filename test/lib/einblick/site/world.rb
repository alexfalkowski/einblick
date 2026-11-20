# frozen_string_literal: true

module Einblick
  module Site
    OUTCOME_FILTERS = {
      'empty' => { 'service' => 'missing-site-service' },
      'broken link' => { 'page_token' => 'broken-page' },
      'dates out of order' => { 'end_time' => '2026-11-19T11:04:04Z' },
      'invalid dates' => { 'start_time' => 'invalid' },
      'wide date range' => { 'end_time' => '2026-11-27T11:04:05Z' },
      'invalid filter' => { 'trace_id' => 'invalid' }
    }.freeze
    MARKUP_TERM = '<b>message</b>'
    MARKUP_MESSAGE = "<script>telemetry</script>#{'ɸ' * 16}#{MARKUP_TERM}#{'é' * 16}".freeze
    MISSING_TERM = '<img src=x>missing message'
    RELATED_LOG_FILTERS = { 'page_size' => '1', 'text' => 'first', 'severity' => 'INFO' }.freeze
    FIXTURE_TRACE_ID = '0102030405060708090a0b0c0d0e0f10'

    # Investigates logs using the browser routes and the existing acknowledged OTLP fixtures.
    module World
      def open_logs
        @response = site_client.open('/logs', 'en')
      end

      def open_logs_with_assets
        @log_assets = site_client.load_log_assets(open_logs)
      end

      def investigate_logs(layout, languages, overrides = {})
        filters = @query.merge(overrides)
        @response = if layout == 'full'
                      site_client.open("/logs?#{URI.encode_www_form(filters)}", languages)
                    else
                      site_client.submit('/logs', filters, languages)
                    end
      end

      def submit_browser_filters(filters)
        @browser_filters = JSON.parse(filters)
        investigate_logs('partial', 'en', @browser_filters)
      end

      def choose_time_range(preset, page: investigate_logs('full', 'en'), layout: 'partial')
        @preset_started = Time.now.utc
        @response = site_client.submit_log_form(page, 'en', submitter: preset, layout: layout)
        @preset_finished = Time.now.utc
      end

      def choose_configured_time_range(preset, minutes)
        with_query_profile("query_range_#{minutes}m") do
          @preset_page = open_logs
          choose_time_range(preset, page: @preset_page)
        end
      end

      def submit_displayed_search
        @response = site_client.submit_log_form(investigate_logs('full', 'en'), 'en')
      end

      def clear_message_search(layout)
        @empty_message_search = investigate_logs('full', 'en', 'text' => MISSING_TERM, 'severity' => 'WARN')
        @response = site_client.submit_log_form(@empty_message_search, 'en', submitter: 'Clear search', layout: layout)
      end

      def open_saved_search(start_time, end_time)
        @saved_time_range = { 'start_time' => start_time, 'end_time' => end_time }
        investigate_logs('full', 'en', @saved_time_range)
      end

      def open_utc_bookmark(start_utc, end_utc)
        investigate_logs('full', 'en', 'start_utc' => start_utc, 'end_utc' => end_utc)
      end

      def investigate_log_outcome(outcome, layout, languages)
        investigate_logs(layout, languages, OUTCOME_FILTERS.fetch(outcome))
      end

      def read_log_pages(filters = { 'page_size' => 2 })
        investigate_logs('full', 'en', filters)
        @site_pages = [@response]
        2.times do
          link = Nokogiri::HTML5.fragment(@response.body).at_css('a.next')
          break unless link

          @response = site_client.submit(link['hx-put'], {}, 'en')
          @site_pages << @response
        end
      end

      def find_related_logs
        read_log_pages(RELATED_LOG_FILTERS)
        @response = site_client.open_related_logs(@site_pages.fetch(1), 'en')
      end

      def search_and_page_without_htmx
        choose_time_range('1 hour', layout: 'full')
        @native_pages = [@response, site_client.open_next_page(@response, 'en')]
      end

      def submit_logs_with_storage_unavailable
        with_unavailable_log_storage { investigate_logs('partial', 'de') }
        @unavailable_response = @response
        investigate_logs('partial', 'de')
      end

      def submit_logs_with_expired_budget
        with_query_profile('query_timeout') { investigate_logs('partial', 'es') }
      end

      private

      def site_client
        HTTP.new('http://localhost:11000')
      end
    end
  end
end
