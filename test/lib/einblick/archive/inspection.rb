# frozen_string_literal: true

module Einblick
  module Archive
    # Inspect completed Parquet and durable batches after stopping the server.
    module World
      ARCHIVE_ROWS = 'resource, scope, record, timestamp_ns, observed_timestamp_ns, received_timestamp_ns, event_timestamp_ns'

      def inspect_archive
        with_log_database do |connection|
          inspect_archive_database(connection)
          inspect_archive_files(connection)
        end
        @archive_checksums = @archive_file_checksums.values
        @archive_partial_exists = !Dir.empty?(PENDING)
        @archive_inspected_ns = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
      end

      def inspect_archive_database(connection)
        @archive_batches = connection.query(<<~SQL).to_a
          SELECT id::VARCHAR, archive_day::VARCHAR, content_sha256, parquet_sha256
          FROM log_archive_batches ORDER BY created_at, id
        SQL
        @archive_members = connection.query('SELECT log_id, batch_id::VARCHAR FROM log_archive_members ORDER BY log_id').to_a
        @stored_archive_logs = connection.query(Logs::World::LOGS_SQL, 0).to_a
      end

      def inspect_archive_files(connection)
        files = read_archive_files(connection)
        @archive_partitions = files.transform_values { |rows| rows.map(&:last) }
        inspect_archive_identity(files)
        @archive_rows = files.values.flatten(1).sort_by(&:first).map { |row| row.drop(1) }
      end

      def inspect_archive_identity(files)
        @archive_file_members = files.transform_values { |rows| rows.map(&:first).sort }
        @archive_file_checksums = files.keys.to_h { |path| [path, Digest::SHA256.file(path).hexdigest] }
      end

      def read_archive_files(connection)
        archive_files.to_h do |path|
          [path, connection.query("SELECT log_id, #{ARCHIVE_ROWS} FROM read_parquet(?, hive_partitioning = false)", path).to_a]
        end
      end

      def inspect_publication
        @published_keys = @floci.keys
        key = @published_keys.fetch(0)
        content = @floci.download(key)
        @published_objects = { key => Digest::SHA256.hexdigest(content) }
        @retained_staging_files = archive_files
        with_log_database do |connection|
          inspect_published_parquet(connection, content)
          inspect_published_state(connection)
        end
      end

      def inspect_published_parquet(connection, content)
        path = File.join(WORKSPACE, 'download.parquet')
        File.binwrite(path, content)
        @published_rows = connection.query(<<~SQL, path).to_a
          SELECT #{ARCHIVE_ROWS} FROM read_parquet(?, hive_partitioning = false) ORDER BY log_id
        SQL
      ensure
        FileUtils.rm_f(path)
      end

      def inspect_published_state(connection)
        @published_state = publication_batches(connection)
        @archive_members = connection.query('SELECT log_id, batch_id::VARCHAR FROM log_archive_members ORDER BY log_id').to_a
      end

      def publication_batches(connection)
        connection.query(<<~SQL).to_a
          SELECT id::VARCHAR, archive_day::VARCHAR, content_sha256, parquet_sha256,
                 published_sha256, published_at IS NOT NULL, staging_cleaned_at IS NOT NULL
          FROM log_archive_batches ORDER BY id
        SQL
      end

      def inspect_interrupted_publication
        files = archive_files.to_h { |path| [File.basename(path, '.parquet'), Digest::SHA256.file(path).hexdigest] }
        with_log_database { |connection| @interrupted_publication = { files: files, batches: publication_batches(connection) } }
      end

      def archive_receipt_day
        receipt_log = @stored_archive_logs.find { |row| row.values_at(3, 4).all?(&:zero?) }
        Time.at(receipt_log.fetch(5) / 1_000_000_000).utc.strftime('%F')
      end

      def archive_event_day
        timestamp = log_query_records(@archive_request).first.time_unix_nano
        Time.at(timestamp / 1_000_000_000).utc.strftime('%F')
      end
    end
  end
end
