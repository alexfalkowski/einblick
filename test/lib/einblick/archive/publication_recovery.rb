# frozen_string_literal: true

module Einblick
  module Archive
    # Exercises publication recovery through Floci and the normal server.
    module World
      def recover_from_checksum_mismatch
        with_floci do
          @floci.corrupt_verification
          observe_publication_failure(/remote log archive checksum verification failed/) do
            acknowledge_archive_logs(@archive_request)
          end
          inspect_interrupted_publication
          @floci.restore
          run_publication
          inspect_publication
        end
      end

      def recover_live_corrupt_staging
        with_floci do
          @floci.pause_access
          run_publication do
            acknowledge_archive_logs(@archive_request)
            wait_for { archive_diagnostics }.to include('remote log archive publication failed')
            @original_publication_key = corrupt_staged_file.delete_prefix("#{WORKSPACE}/")
            @floci.restore
          end
          inspect_publication
        end
      end

      def publish_against_competing_object(metadata)
        with_floci do
          @floci.compete_on_completion(archive_files.fetch(0), metadata)
          observe_publication_failure(competing_object_failure(metadata))
          inspect_interrupted_publication
          @competing_checksum = @floci.competing_checksum
          @visible_objects = remote_archive_checksums
        end
      end

      def competing_object_failure(metadata)
        return /remote log archive checksum verification failed/ if metadata == 'attempted'

        /remote log archive does not match a recorded upload/
      end

      def recover_late_original_upload
        with_floci do
          interrupt_deferred_upload
          lose_staged_file
          @floci.commit_on_retry
          run_publication
          inspect_publication
          @attempted_checksums = @floci.attempted_checksums
        end
      end

      def interrupt_deferred_upload
        @floci.defer_commit
        with_server_profile('publication') do
          wait_for { @floci.attempted_checksums.size }.to eq(1)
          interrupt_publication_process
        end
      end

      def recover_failed_archive_cleanup
        with_floci do
          observe_failed_staging_cleanup(archive_files.fetch(0))
          @ambiguous_objects = remote_archive_checksums
          run_publication
          inspect_publication
        end
      end

      def recover_corrupt_staging_cleanup
        with_floci do
          interrupt_publication_after_commit
          path = corrupt_staged_file
          @floci.restore
          observe_failed_staging_cleanup(path)
          run_publication
          inspect_publication
        end
      end

      def observe_failed_staging_cleanup(path)
        with_unwritable_directory(File.dirname(path)) do
          observe_publication_failure(/remote log archive publication failed.*permission denied/i)
          inspect_interrupted_publication
        end
      end

      def reconcile_unreadable_staging
        with_floci do
          interrupt_publication_after_commit
          @floci.restore
          with_unreadable_archive_file do
            run_publication { wait_for { archive_diagnostics }.to include('local log archive recovery failed') }
          end
          inspect_publication
        end
      end

      def reconcile_without_restaging
        with_floci do
          interrupt_publication_after_commit
          path = lose_staged_file
          @floci.restore
          with_unwritable_directory(File.dirname(path)) do
            run_publication
            @restaging_failed = archive_diagnostics.include?('local log archive export failed')
            inspect_publication
          end
        end
      end
    end
  end
end
