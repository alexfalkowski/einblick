# frozen_string_literal: true

module Einblick
  module Site
    # Investigates logs using the browser routes and the existing acknowledged OTLP fixtures.
    module World
      def open_logs
        @response = site_client.open('/logs', 'en')
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

      def choose_last_hour
        @preset_started = Time.now.utc
        submit_rendered_log_form(preset: '1h')
        @preset_finished = Time.now.utc
      end

      def submit_displayed_utc_range
        submit_rendered_log_form
      end

      def choose_utc_range(start_time, end_time)
        investigate_logs('partial', 'en', 'start_utc' => start_time, 'end_utc' => end_time)
      end

      def investigate_log_outcome(outcome, layout, languages)
        filters = outcome == 'empty' ? { 'text' => 'a message that does not exist' } : { 'end_time' => @query.fetch('start_time') }
        investigate_logs(layout, languages, filters)
      end

      def read_log_pages
        investigate_logs('full', 'en', 'page_size' => 2)
        @site_pages = [@response]
        2.times do
          link = Nokogiri::HTML5.fragment(@response.body).at_css('a.next')
          break unless link

          @response = site_client.submit(link['hx-put'], {}, 'en')
          @site_pages << @response
        end
      end

      def submit_logs_with_storage_unavailable
        with_unavailable_log_storage { investigate_logs('partial', 'de') }
        @unavailable_response = @response
        investigate_logs('partial', 'de')
      end

      def submit_logs_with_expired_budget
        with_query_profile('query_timeout') { investigate_logs('partial', 'es') }
      end

      def prepare_markup_log
        prepare_searchable_logs
        @query_service = "#{@query_service}-<b>service</b>"
        @query['service'] = @query_service
        request = query_fixture('log_queries')
        scope = request.resource_logs.first.scope_logs.first
        scope.log_records.replace([log_with_markup(scope.log_records[2])])
        acknowledge_query_export(request)
      end

      def prepare_blank_logs
        prepare_searchable_logs
        @query_service = "#{@query_service}-blank"
        @query['service'] = @query_service
        start = Einblick::Logs::World::QUERY_TIME
        request = timed_query_export([start, start + 1])
        records = log_query_records(request)
        records[0].body.string_value = ''
        records[1].body.string_value = " \t"
        acknowledge_query_export(request)
      end

      def prepare_unsigned_logs
        prepare_searchable_logs
        upper = 2**64
        acknowledge_query_export(timed_query_export([upper - 1, upper - 2]))
        @query.merge!('start_time' => query_time(upper - 2), 'end_time' => query_time(upper))
      end

      private

      def submit_rendered_log_form(preset: nil)
        investigate_logs('full', 'en')
        @response = site_client.submit_log_form(@response, 'en', preset: preset)
      end

      def log_with_markup(record)
        record.body.string_value = '<script>telemetry</script><b>message</b>'
        record.attributes.first.value.string_value = '<img src=x>attribute'
        record.severity_number = 100
        record
      end

      def site_client
        HTTP.new('http://localhost:11000')
      end
    end
  end
end
