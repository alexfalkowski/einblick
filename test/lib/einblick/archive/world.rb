# frozen_string_literal: true

module Einblick
  module Archive
    # Runs local export and restart scenarios with the normal server and a disposable staging directory.
    module World
      WORKSPACE = 'reports/archive/resource=main'
      ARCHIVE_DIRECTORY = File.join(WORKSPACE, 'v1')
      PENDING = File.join(ARCHIVE_DIRECTORY, '.pending')

      def prepare_archive_storage(create_export_directory: true)
        prepare_log_database
        initialize_log_database
        FileUtils.rm_rf(WORKSPACE)
        FileUtils.mkdir_p(create_export_directory ? ARCHIVE_DIRECTORY : WORKSPACE)
      end

      def acknowledge_archive_logs(request)
        prepare_export('logs', request)
        response = export_telemetry('logs', @payload)
        expect(response).to be_a(Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceResponse)
        expect(response.partial_success).to be_nil
      end

      def stage_log_archive(request, file_count)
        commit_archive_fixture(request)
        stage_ready_archive(file_count, archive_files.size)
        inspect_archive
      end

      def stage_ready_archive(file_count, existing)
        @archive_offset = File.size('reports/server.log')
        with_server_profile('archive') { wait_for_archive(file_count, existing) }
      end

      def commit_archive_fixture(request)
        acknowledge_archive_logs(request)
        age_pending_archive_receipts
      end

      def age_pending_archive_receipts
        cutoff = daily_midnight
        shift = 3 * DAY_NANOSECONDS
        with_log_database do |connection|
          connection.query(File.read('fixtures/age_archive_receipts.sql'), shift, shift, cutoff)
        end
        @export_started_ns -= shift if @export_started_ns && @export_started_ns >= cutoff
        @query_receipt_windows&.transform_values! do |window|
          window.begin >= cutoff ? (window.begin - shift)..(window.end - shift) : window
        end
      end

      def wait_for_archive(file_count, existing)
        # Wait for the durable completion update after the Parquet file is renamed and synced.
        wait(timeout: 10).for { archive_diagnostics.scan('local log archive export completed').size }.to eq(file_count - existing)
        expect(archive_files.size).to eq(file_count)
      end

      def stage_late_log_archive
        stage_log_archive(@archive_request, 1)
        @first_archive_path = archive_files.fetch(0)
        @first_archive_checksum = Digest::SHA256.file(@first_archive_path).hexdigest
        stage_log_archive(@archive_request, 2)
      end

      def stage_after_workspace_returns
        commit_archive_fixture(@archive_request)
        day = prepare_archive_day_directory
        with_unwritable_directory(day) do |permissions|
          with_server_profile('archive') { resume_after_workspace_returns(day, permissions) }
        end
        inspect_archive
      end

      def resume_after_workspace_returns(day, permissions)
        with_replaced_archive_workspace do
          wait_for { archive_diagnostics.scan('log archive workspace changed since startup').size }.to be >= 2
          @replacement_archive_contents = Dir.children(WORKSPACE).sort
          @replacement_archive_version_contents = Dir.children(ARCHIVE_DIRECTORY)
        end
        File.chmod(permissions, day)
        wait_for_archive(1, 0)
      end

      def retry_archive_publication
        commit_archive_fixture(@archive_request)
        with_unwritable_directory(prepare_archive_day_directory) do
          with_server_profile('archive') { observe_failed_publication }
        end
        stage_ready_archive(1, 0)
        inspect_archive
      end

      def prepare_archive_day_directory(day = archive_event_day)
        File.join(ARCHIVE_DIRECTORY, 'signal=logs', "day=#{day}").tap { |path| FileUtils.mkdir_p(path) }
      end

      def observe_failed_publication
        failure = /local log archive export failed.*batch_id=([\w-]+).*renameat (\S+) /
        wait_for { archive_diagnostics }.to match(failure)
        _, @failed_publication_batch_id, partial = archive_diagnostics.match(failure).to_a
        @failed_publication_files = Dir.glob(File.join(ARCHIVE_DIRECTORY, File.dirname(partial))) + archive_files
      end

      def with_replaced_archive_workspace
        original = "#{WORKSPACE}.original"
        File.rename(WORKSPACE, original)
        begin
          FileUtils.mkdir_p(ARCHIVE_DIRECTORY)
          yield
        ensure
          FileUtils.rm_rf(WORKSPACE)
          File.rename(original, WORKSPACE)
        end
      end

      def archive_diagnostics
        File.read('reports/server.log', nil, @archive_offset || @receipt_offset)
      end

      def archive_files
        Dir.glob('v1/signal=logs/day=*/*.parquet', base: WORKSPACE).map { |path| File.join(WORKSPACE, path) }
      end
    end
  end
end
