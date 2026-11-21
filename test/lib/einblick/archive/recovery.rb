# frozen_string_literal: true

module Einblick
  module Archive
    # Staging failure and restart actions use the ordinary server profile.
    module World
      def prepare_archive_recovery(state)
        if state == 'partial'
          fail_archive_write
          write_interrupted_output
        else
          stage_log_archive(@archive_request, 1)
          interrupt_completed_archive(state)
        end
        @original_archive_batches = @archive_batches
        @original_archive_members = @archive_members
      end

      def write_interrupted_output
        path = File.join(PENDING, 'interrupted', '.logs.parquet.partial')
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, 'PAR1 interrupted output')
      end

      def interrupt_completed_archive(state)
        path = archive_files.fetch(0)
        case state
        when 'unmarked'
          with_log_database { |connection| connection.query('UPDATE log_archive_batches SET parquet_sha256 = NULL') }
        when 'missing'
          File.delete(path)
        when 'corrupt'
          File.binwrite(path, 'invalid parquet content')
        end
      end

      def fail_archive_write
        with_server_profile('archive') do
          with_unwritable_directory(ARCHIVE_DIRECTORY) do
            acknowledge_archive_logs(@archive_request)
            wait_for { archive_diagnostics }.to include('local log archive export failed')
            Process.kill('KILL', Nonnative.pool.process_by_name('server').memory.pid)
          end
        end
        inspect_archive
        expect_pending_archive
      end

      def with_unwritable_directory(path)
        permissions = File.stat(path).mode & 0o777
        File.chmod(0o500, path)
        yield
      ensure
        File.chmod(permissions, path) if permissions
      end

      def expect_pending_archive
        expect(@archive_batches.size).to eq(1)
        expect(@archive_batches.first.last).to be_nil
        expect(archive_files).to be_empty
      end

      def recover_log_archive
        @archive_offset = File.size('reports/server.log')
        with_server_profile('archive') do
          wait_for { archive_diagnostics }.to include('local log archive export completed')
        end
        inspect_archive
      end

      def recover_before_staging_new_logs
        acknowledge_archive_logs(@archive_request)
        @archive_offset = File.size('reports/server.log')
        with_server_profile('archive') { wait_for_archive(2, 0) }
        @completed_archive_ids = archive_diagnostics.scan(/local log archive export completed.*batch_id=([\w-]+)/).flatten
        inspect_archive
      end

      def export_during_archive_recovery
        with_unreadable_archive_file do |path, permissions|
          with_server_profile('archive') do
            acknowledge_archive_logs(@archive_request)
            inspect_blocked_archive_recovery
            File.chmod(permissions, path)
            wait_for_archive(2, 1)
          end
        end
        inspect_archive
      end

      def inspect_blocked_archive_recovery
        wait_for { archive_diagnostics.scan('local log archive recovery failed').size }.to be >= 2
        @archive_file_count_before_restore = archive_files.size
        @archive_completed_before_restore = archive_diagnostics.include?('local log archive export completed')
        query_during_archive_recovery
      end

      def query_during_archive_recovery
        timestamp = log_query_records(@archive_request).first.time_unix_nano
        @query = { 'start_time' => query_time(timestamp - 1), 'end_time' => query_time(timestamp + 1) }
        query_logs
        @archive_query_response = @response
      end

      def with_unreadable_archive_file
        path = archive_files.fetch(0)
        permissions = File.stat(path).mode & 0o777
        File.chmod(0o000, path)
        yield path, permissions
      ensure
        File.chmod(permissions, path) if permissions
      end
    end
  end
end
