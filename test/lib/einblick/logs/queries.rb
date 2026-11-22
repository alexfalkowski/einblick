# frozen_string_literal: true

module Einblick
  module Logs
    # Query scenarios use acknowledged OTLP records and the real HTTP front door.
    module World
      QUERY_TIME = 1_795_086_245_123_456_789

      def prepare_searchable_logs
        @query_service = "query-#{SecureRandom.uuid}"
        @query_receipt_windows = {}
        @query_record_count = 0
        request = query_fixture('log_queries')
        records = log_query_records(request)
        yield records if block_given?
        acknowledge_query_export(request)
        @query = { 'start_time' => query_time(QUERY_TIME), 'end_time' => query_time(QUERY_TIME + 10), 'service' => @query_service }
        @expected_query_records = [5, 4, 3, 2, 1].map { |index| records[index] }
      end

      def query_time(nanoseconds)
        Time.at(nanoseconds.div(1_000_000_000), nanoseconds % 1_000_000_000, :nanosecond).utc.iso8601(9)
      end

      def query_logs(overrides = {})
        @response = HTTP.new('http://localhost:11000').list(@query.merge(overrides))
      end

      def query_all_services(selection)
        query_logs(selection == 'empty' ? { 'service' => '' } : {})
      end

      def query_fixture(name)
        fixture = File.read("fixtures/#{name}.json").gsub('fixture-query-service', @query_service)
        Einblick::OTLP.request_type('logs').decode_json(fixture)
      end

      def log_query_records(request)
        request.resource_logs.flat_map { |resource| resource.scope_logs.flat_map { |scope| scope.log_records.to_a } }
      end

      def acknowledge_query_export(request)
        prepare_export('logs', request)
        @response = export_query_logs(request, @payload)
      end

      def export_query_logs(request, payload)
        started = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
        response = export_telemetry('logs', payload)
        received = started..Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
        records = log_query_records(request)
        records.each { |record| @query_receipt_windows[record] = received }
        @query_record_count += records.size
        response
      end

      def collect_log_pages(first_page, page_size: 2, identity: :id)
        page = first_page
        @query_pages = []
        loop do
          expect(page).to advance_log_query(@query_pages, @query_record_count, identity)
          @query_pages << page
          break if page.next_page_token.empty?

          page = block_given? ? yield(page.next_page_token) : next_log_query_page(page.next_page_token, page_size: page_size)
        end
        @query_logs = @query_pages.flat_map { |part| part.logs.to_a }
      end

      def next_log_query_page(token, page_size:)
        query_logs('page_size' => page_size, 'page_token' => token)
        raise "query failed: #{@response.code} #{@response.body}" unless @response.code == 200

        Einblick::V1::ListLogsResponse.decode_json(@response.body)
      end

      def prepare_first_log_page
        query_logs('page_size' => 2)
        raise "first page failed: #{@response.body}" unless @response.code == 200

        @first_log_page = Einblick::V1::ListLogsResponse.decode_json(@response.body)
      end

      def query_pages_during_ingestion
        # Include newer, equal-time and late records in the fixed selected window.
        @arrival_request = query_fixture('log_query_arrivals')
        @arrival_response = export_query_logs(@arrival_request, @arrival_request.class.encode(@arrival_request))
        collect_log_pages(@first_log_page)
        query_logs
        @fresh_query = Einblick::V1::ListLogsResponse.decode_json(@response.body)
      end

      def query_after_restart(mode)
        Process.kill('KILL', Nonnative.pool.process_by_name('server').memory.pid) if mode == 'interrupted'
        Nonnative.stop
        Nonnative.start
        collect_log_pages(@first_log_page)
      end

      def prepare_more_than_one_query_page
        @query_service = "#{@query_service}-bounded"
        @query['service'] = @query_service
        request = query_fixture('log_query_times')
        records = request.resource_logs.first.scope_logs.first.log_records
        record = records.first
        record.time_unix_nano = QUERY_TIME
        records.replace(Array.new(105, record))
        acknowledge_query_export(request)
        @expected_query_records = records.to_a
      end

      def query_default_sized_pages
        query_logs('page_size' => 0)
        first = Einblick::V1::ListLogsResponse.decode_json(@response.body)
        query_logs('page_token' => first.next_page_token)
        @query_pages = [first, Einblick::V1::ListLogsResponse.decode_json(@response.body)]
        @query_logs = @query_pages.flat_map { |page| page.logs.to_a }
      end
    end
  end
end
