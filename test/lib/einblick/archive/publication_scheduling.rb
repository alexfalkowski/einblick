# frozen_string_literal: true

module Einblick
  module Archive
    # Exercises progress across two distinct archive days while one batch is blocked.
    module World
      def stage_two_archive_batches
        prepare_archive_publication
        stage_log_archive(@archive_request, 1)
        stage_log_archive(next_day_archive_request, 2)
        inspect_staged_publications
      end

      def publish_past_blocked_staging
        directory = prepare_archive_day_directory
        with_floci do
          with_unwritable_directory(directory) do |permissions|
            run_publication(query_local: false) do
              capture_progress_during_blocked_staging
              File.chmod(permissions, directory)
              wait(timeout: 10).for { @published_after_staging_recovered = @floci.keys }.to include(@blocked_staging_key)
            end
          end
        end
      end

      def capture_progress_during_blocked_staging
        wait(timeout: 10).for do
          @blocked_staging_id = archive_diagnostics[/local log archive export failed.*batch_id=([\w-]+)/, 1]
        end.not_to be_nil
        @blocked_staging_key = "v1/signal=logs/day=#{archive_event_day}/#{@blocked_staging_id}.parquet"
        wait_for_publication
        @published_while_staging_blocked = @floci.keys
      end

      def next_day_archive_request
        request = representative_export('logs')
        log_query_records(request).each { |record| record.time_unix_nano += 86_400_000_000_000 }
        request
      end

      def inspect_staged_publications
        paths = archive_files.sort
        @earlier_archive, @later_archive = paths
        @earlier_key, @later_key = paths.map { |path| path.delete_prefix("#{WORKSPACE}/") }
        @staged_checksums = paths.to_h { |path| [File.basename(path, '.parquet'), Digest::SHA256.file(path).hexdigest] }
      end

      def reconcile_past_missing_object
        record_staged_uploads
        with_floci do
          @floci.upload_fixture(@later_key, @later_archive, @staged_checksums.fetch(File.basename(@later_archive, '.parquet')))
          with_unreadable_archive_file(@earlier_archive) do
            observe_publication_failure(/local log archive recovery failed/) { wait_for_later_archive_cleanup }
          end
          inspect_publication_progress
        end
      end

      def publish_past_blocked_cleanup
        @retained_batch_id = File.basename(@earlier_key, '.parquet')
        @evicted_batch_id = File.basename(@later_key, '.parquet')
        @retained_archive_record_count = log_query_records(@archive_request).size
        with_floci do
          with_unwritable_directory(File.dirname(@earlier_archive)) { evict_past_blocked_cleanup }
          inspect_publication_progress
        end
        inspect_eviction
      end

      def evict_past_blocked_cleanup
        with_eviction_profile do
          wait(timeout: 10).for { archive_diagnostics }.to match(/remote log archive publication failed.*permission denied/i)
          wait_for_archive_evictions(@later_key)
        end
      end

      def publish_past_blocked_repair
        @later_archive_request = next_day_archive_request
        commit_archive_fixture(@later_archive_request)
        with_floci do
          @floci.pause_access
          with_unwritable_directory(File.dirname(@first_archive_path)) { publish_during_blocked_repair }
          inspect_publication
        end
      end

      def publish_during_blocked_repair
        later_directory = prepare_archive_day_directory(archive_event_day(@later_archive_request))
        with_unwritable_directory(later_directory) do |permissions|
          run_publication do
            wait_for { archive_diagnostics }.to include('remote log archive publication failed')
            corrupt_staged_file
            @floci.restore
            wait_for { archive_diagnostics }.to match(/remote log archive publication failed.*permission denied/i)
            File.chmod(permissions, later_directory)
          end
        end
      end

      def record_staged_uploads
        with_log_database do |connection|
          @staged_checksums.each do |id, checksum|
            connection.query('INSERT INTO log_archive_uploads (batch_id, parquet_sha256) VALUES (?, ?)', id, checksum)
          end
        end
      end

      def wait_for_later_archive_cleanup
        id = File.basename(@later_archive, '.parquet')
        wait_for { archive_diagnostics }.to match(/remote log archive publication completed.*batch_id=#{id}/)
      end

      def inspect_publication_progress
        inspect_interrupted_publication
        @visible_objects = remote_archive_checksums
      end
    end
  end
end
