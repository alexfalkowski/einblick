# frozen_string_literal: true

module Einblick
  module Archive
    # Drives publication using the real OTLP, query and S3 boundaries.
    module World
      def prepare_archive_publication
        prepare_archive_storage
        @archive_request = representative_export('logs')
      end

      def stage_before_publication
        prepare_archive_publication
        stage_log_archive(@archive_request, 1)
        @original_archive_batches = @archive_batches
        @original_archive_members = @archive_members
      end

      def publish_log_archive
        commit_archive_fixture(@archive_request)
        with_floci do
          run_publication
          inspect_publication
        end
      end

      def publish_staged_log_archive
        with_floci do
          run_publication
          inspect_publication
        end
      end

      def recover_ambiguous_publication
        with_floci do
          interrupt_publication_after_commit
          lose_staged_file
          run_publication { restore_after_regeneration }
          inspect_publication
        end
      end

      def lose_staged_file
        path = archive_files.fetch(0)
        File.delete(path)
        path
      end

      def interrupt_publication_after_commit
        @floci.lose_acknowledgement
        with_server_profile('publication') do
          wait_for { @floci.acknowledgement_waiting? }.to be(true)
          interrupt_publication_process
        end
        @floci.release_acknowledgement
        @ambiguous_objects = remote_archive_checksums
      end

      def restore_after_regeneration
        wait_for { archive_diagnostics }.to include('local log archive export completed')
        checksum = Digest::SHA256.file(archive_files.fetch(0)).hexdigest
        expect(@ambiguous_objects.values).not_to include(checksum)
        @floci.restore
      end

      def remote_archive_checksums
        @floci.keys.to_h { |key| [key, Digest::SHA256.hexdigest(@floci.download(key))] }
      end

      def hold_staged_archive
        archive_files.fetch(0).delete_prefix("#{WORKSPACE}/").tap { |key| @floci.hold_archive_read(key) }
      end

      def with_floci
        @floci = Floci.new
        @floci.start
        yield
      ensure
        @floci.stop
      end

      def run_publication(profile = 'publication', query_local: true)
        @archive_offset = File.size('reports/server.log')
        with_publication_profile(profile) do
          yield if block_given?
          wait_for_publication
        end
        query_during_archive_recovery if query_local
      end

      def with_publication_profile(profile = 'publication', &)
        @floci.defer_archive_eviction = true
        with_server_profile(profile, &)
      ensure
        @floci.defer_archive_eviction = false
      end

      def wait_for_publication
        wait(timeout: 10).for { archive_diagnostics }.to include('remote log archive publication completed')
      end

      def observe_publication_failure(failure)
        @archive_offset = File.size('reports/server.log')
        with_server_profile('publication') do
          yield if block_given?
          wait_for { archive_diagnostics }.to match(failure)
        end
      end

      def interrupt_publication_process
        Process.kill('KILL', Nonnative.pool.process_by_name('server').memory.pid)
      end
    end
  end
end
