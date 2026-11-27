# frozen_string_literal: true

module Einblick
  module Archive
    # Exercises archive activity admission while another day's search is waiting on storage.
    module World
      def prepare_activity_archive_days
        prepare_archive_storage
        prepare_searchable_logs
        request = other_day_archive_fixture
        @held_archive_day = archive_event_day(request)
        acknowledge_query_export(request)
      end

      def page_while_archive_search_is_loading(search)
        with_floci do
          publish_searchable_logs { wait(timeout: 10).for { @floci.keys.size }.to eq(2) }
          key = @floci.keys.find { |object| object.include?("/day=#{@held_archive_day}/") }
          prepare_log_database
          initialize_log_database
          with_server_profile('history_retention') { page_during_archive_search(key, search) }
        end
      end

      private

      def page_during_archive_search(key, search)
        first = first_archived_log_page
        path = { 'activity chart' => '/logs/activity', 'log page' => '/logs' }.fetch(search)
        @held_archive_response = with_held_archive_read(key, "#{path}?#{@held_archive_query}") do
          page_through_archived_logs(first)
          @archive_search_still_loading = @floci.archive_read_waiting?(key)
        end
        @retried_archive_activity = site_client.open_log_activity(first, 'en')
        @held_activity_page = site_client.open("/logs?#{@held_archive_query}", 'en') if search == 'activity chart'
      end

      def with_held_archive_read(key, path)
        @floci.hold_archive_read(key)
        pending = Thread.new { site_client.open(path, 'en') }
        wait_for { @floci.archive_read_waiting?(key) }.to be(true)
        yield
        @floci.release_archive_read(key)
        pending.value
      ensure
        @floci.release_archive_read(key)
        pending&.join
      end

      def other_day_archive_fixture
        request = query_fixture('log_queries')
        resource = request.resource_logs.first
        request.resource_logs.replace([resource])
        records = resource.scope_logs.first.log_records
        @held_archive_record = records.fetch(1)
        @held_archive_record.time_unix_nano -= DAY_NANOSECONDS
        records.replace([@held_archive_record])
        @held_archive_query = archive_search_range_for(@held_archive_record.time_unix_nano)
        request
      end

      def archive_search_range_for(timestamp)
        URI.encode_www_form(service: @query_service, start_time: query_time(timestamp), end_time: query_time(timestamp + 1))
      end
    end
  end
end
