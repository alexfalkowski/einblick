# frozen_string_literal: true

module Einblick
  module Archive
    # Synthetic log inputs exercise calendar boundaries and archive sizing.
    module World
      def archive_timestamp_fixture
        request = representative_export('logs')
        add_archive_context(request)
        midnight = 86_400_000_000_000
        times = [[midnight - 1, 1], [midnight, 0], [midnight, 0], [midnight, 0], [0, 18_446_744_073_709_551_615], [0, 0]]
        log_query_records(request).zip(times).each { |record, times| record.time_unix_nano, record.observed_time_unix_nano = times }
        request
      end

      def add_archive_context(request)
        resources = request.resource_logs
        resource = resources.first
        resources << second_archive_resource(resource)
        resource.scope_logs << second_archive_scope(resource.scope_logs.first)
      end

      def second_archive_resource(original)
        resource = original.class.decode(original.to_proto)
        resource.resource.attributes.first.value.string_value = 'second-archive-host'
        records = resource.scope_logs.first.log_records
        records << records.first.dup
        resource
      end

      def second_archive_scope(original)
        scope = original.class.decode(original.to_proto)
        scope.scope.name = 'second-archive-scope'
        scope.log_records.replace([scope.log_records.first])
        scope
      end

      def large_archive_fixture
        request = representative_export('logs')
        record = request.resource_logs.first.scope_logs.first.log_records.first
        record.body.bytes_value = Random.new(1).bytes(950_000)
        request
      end

      def same_day_archive_fixture
        request = representative_export('logs')
        records = request.resource_logs.first.scope_logs.first.log_records
        records << records.first.dup
        random = Random.new(1)
        records.each { |record| record.body.bytes_value = random.bytes(22_000) }
        request
      end

      def shared_archive_context_fixture
        request = representative_export('logs')
        resource = request.resource_logs.first
        scope = resource.scope_logs.first
        add_archive_context_bytes(resource.resource, 9000)
        add_archive_context_bytes(scope.scope, 9000)
        scope.log_records << scope.log_records.first.dup
        request
      end

      def add_archive_context_bytes(header, size)
        common = Opentelemetry::Proto::Common::V1
        value = common::AnyValue.new(bytes_value: Random.new(1).bytes(size))
        header.attributes << common::KeyValue.new(key: 'archive.context', value: value)
      end

      def stage_with_different_parquet_encoding(multipart: false)
        prepare_archive_publication
        stage_log_archive(@archive_request, 1)
        path = archive_files.fetch(0)
        copy = File.join(WORKSPACE, 'repacked.parquet')
        with_log_database do |connection|
          repack_parquet(connection, path, copy)
          File.rename(copy, path)
          pad_parquet_for_multipart(path) if multipart
          connection.query('UPDATE log_archive_batches SET parquet_sha256 = ?', Digest::SHA256.file(path).hexdigest)
        end
      end

      def pad_parquet_for_multipart(path)
        File.open(path, 'r+b') do |file|
          file.seek(-8, IO::SEEK_END)
          footer_size = file.read(4).unpack1('V') + 8
          file.seek(-footer_size, IO::SEEK_END)
          footer = file.read
          # The footer points to the original column offsets. Move it past the
          # pinned client's 64 MiB multipart threshold without changing the rows.
          file.seek(64 * 1024 * 1024)
          file.write(footer)
        end
      end

      def repack_parquet(connection, path, copy)
        connection.query(<<~SQL, path, copy)
          COPY (SELECT * FROM read_parquet(?, hive_partitioning = false))
          TO (?) (FORMAT PARQUET, COMPRESSION UNCOMPRESSED)
        SQL
      end
    end
  end
end
