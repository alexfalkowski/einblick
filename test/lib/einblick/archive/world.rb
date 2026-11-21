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
        existing = archive_files.size
        with_server_profile('archive') do
          acknowledge_archive_logs(request)
          wait_for_archive(file_count, existing)
        end
        inspect_archive
      end

      def wait_for_archive(file_count, existing)
        wait_for { archive_files.size }.to eq(file_count)
        # File rename precedes the durable completion update and its success log.
        wait_for { archive_diagnostics.scan('local log archive export completed').size }.to eq(file_count - existing)
      end

      def stage_late_log_archive
        @archive_offset = File.size('reports/server.log')
        with_server_profile('archive') do
          acknowledge_archive_logs(@archive_request)
          wait_for_archive(1, 0)
          @first_archive_path = archive_files.fetch(0)
          @first_archive_checksum = Digest::SHA256.file(@first_archive_path).hexdigest
          acknowledge_archive_logs(@archive_request)
          wait_for_archive(2, 0)
        end
        inspect_archive
      end

      def stage_after_workspace_returns
        with_server_profile('archive') do
          with_replaced_archive_workspace do
            acknowledge_archive_logs(@archive_request)
            wait_for { archive_diagnostics.scan('log archive workspace changed since startup').size }.to be >= 2
            @replacement_archive_contents = Dir.children(WORKSPACE).sort
            @replacement_archive_version_contents = Dir.children(ARCHIVE_DIRECTORY)
          end
          wait_for_archive(1, 0)
        end
        inspect_archive
      end

      def retry_archive_publication
        day = File.join(ARCHIVE_DIRECTORY, 'signal=logs', "day=#{archive_event_day}")
        FileUtils.mkdir_p(day)
        with_server_profile('archive') do
          with_unwritable_directory(day) { observe_failed_publication }
          wait_for_archive(1, 0)
        end
        inspect_archive
      end

      def observe_failed_publication
        acknowledge_archive_logs(@archive_request)
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
