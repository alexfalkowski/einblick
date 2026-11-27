# frozen_string_literal: true

module Einblick
  module Archive
    # Drives the archive worker and inspects which batches still occupy local storage.
    module World
      def evict_with_unverified_archive(fault)
        @retained_archive_record_count = @query_record_count
        with_floci do
          publish_searchable_logs
          earlier_key = @floci.keys.fetch(0)
          publish_searchable_logs(query_fixture('log_queries')) { @logs_before_fault = next_log_query_page('', page_size: 100).logs.to_a }
          record_eviction_pair(earlier_key)
          invalidate_archive_object(earlier_key, fault)
          with_archive_eviction { @logs_after_fault = next_log_query_page('', page_size: 100).logs.to_a }
        end
        inspect_eviction
      end

      def prepare_shared_context_batches
        prepare_archive_storage
        stage_log_archive(shared_archive_context_fixture(next_day: true), 2)
        @evicted_batch_id, @retained_batch_id = @archive_batches.map(&:first)
        @sibling_archive_key = staged_archive_key(@retained_batch_id)
        times = @stored_archive_logs.map(&:last)
        @query = { 'start_time' => query_time(times.min), 'end_time' => query_time(times.max + 1) }
        @shared_context_logs_before_eviction = next_log_query_page('', page_size: 3).logs.to_a
      end

      def query_with_local_sibling_batch
        with_floci do
          @floci.hold_archive_read(@sibling_archive_key)
          with_archive_eviction do
            @shared_context_logs_after_eviction = next_log_query_page('', page_size: 3).logs.to_a
          end
        end
        inspect_eviction
      end

      def with_archive_eviction(profile = 'history')
        with_eviction_profile(profile) do
          wait_for { archive_diagnostics }.to include('local log archive eviction completed')
          yield if block_given?
        end
      end

      def with_eviction_profile(profile = 'history', &)
        @archive_offset = File.size('reports/server.log')
        with_server_profile(profile, &)
      end

      def with_retention_profile(&)
        with_floci { with_eviction_profile('history_retention', &) }
      end

      def search_oldest_activity_bucket
        with_retention_profile do
          @activity_bucket_search = open_activity_bucket_after_cutoff
          filters = { 'text' => 'archived error' }
          @activity_bucket_filter = site_client.submit_log_form(
            @activity_bucket_search, 'en', submitter: 'Search', layout: 'full', edits: filters
          )
        end
      end

      def wait_for_archive_evictions(*keys)
        ids = keys.map { |key| File.basename(key, '.parquet') }
        wait(timeout: 10).for do
          archive_diagnostics.scan(/local log archive eviction completed.*batch_id=([\w-]+)/).flatten
        end.to include(*ids)
      end

      def inspect_eviction
        with_log_database do |connection|
          @batch_eviction_status = connection.query('SELECT id::VARCHAR, evicted_at IS NOT NULL FROM log_archive_batches').to_a.to_h
          @local_archive_members = connection.query('SELECT log_id, batch_id::VARCHAR FROM log_archive_members').to_a
          @local_archive_rows = schema_data(connection)
        end
      end

      private

      def open_activity_bucket_after_cutoff
        @seven_day_page = site_client.open('/logs?window=7d', 'en')
        @oldest_activity, link, @activity_bucket_bounds = site_client.oldest_activity_bucket(@seven_day_page, 'en')
        wait_until_history_cutoff_passes(Time.iso8601(@activity_bucket_bounds.fetch('start_time')))
        site_client.open(link, 'en')
      end

      def staged_archive_key(batch_id)
        file = archive_files.find { |path| File.basename(path, '.parquet') == batch_id }
        file.delete_prefix("#{WORKSPACE}/")
      end

      def record_eviction_pair(earlier_key)
        later_key = (@floci.keys - [earlier_key]).fetch(0)
        @retained_batch_id = File.basename(earlier_key, '.parquet')
        @evicted_batch_id = File.basename(later_key, '.parquet')
      end

      def invalidate_archive_object(key, fault)
        case fault
        when 'missing' then @floci.delete_archive(key)
        when 'checksum changed' then @floci.replace_archive(key)
        when 'contents changed without checksum' then @floci.replace_archive(key, keep_checksum: true)
        else raise ArgumentError, "Unknown archive fault: #{fault}"
        end
      end
    end
  end
end
