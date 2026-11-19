# frozen_string_literal: true

module Einblick
  module Logs
    # Storage setup/actions stay in the existing Cucumber/Nonnative lifecycle.
    # DuckDB permits only one writer process: inspect it while the server stops.
    module World
      LOGS_SQL = <<~SQL
        SELECT r.content::VARCHAR, s.content::VARCHAR, l.content::VARCHAR,
               l.timestamp_ns, l.observed_timestamp_ns, l.received_timestamp_ns, l.event_timestamp_ns
        FROM logs l
        JOIN log_scopes s ON s.id = l.scope_id
        JOIN log_resources r ON r.id = s.resource_id
        WHERE l.received_timestamp_ns >= ?
        ORDER BY l.id
      SQL

      def log_database(&)
        DuckDB::Database.open(Einblick.config.duckdb.path) { |database| database.connect(&) }
      end

      def with_log_database(&)
        Nonnative.stop
        log_database(&)
      ensure
        Nonnative.start
      end

      def schema_data(connection)
        %w[logs log_scopes log_resources].to_h do |table|
          [table, connection.query("SELECT * FROM #{table} ORDER BY id").to_a]
        end
      end

      # Reopen with the actual service before reading committed rows. The second
      # close permits the Ruby client to inspect exactly the same database file.
      def reopen_log_storage(mode)
        Process.kill('KILL', Nonnative.pool.process_by_name('server').memory.pid) if mode == 'interrupted'
        Nonnative.stop
        Nonnative.start
        inspect_log_storage
      end

      def inspect_log_storage
        with_log_database do |connection|
          @stored_logs = connection.query(LOGS_SQL, @export_started_ns).to_a
          @storage_snapshot_after = schema_data(connection)
          @storage_inspected_ns = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
        end
      end

      def export_malformed_logs
        prepare_export('logs', Einblick::OTLP.request_type('logs').new)
        @response = export_telemetry('logs', "\xff".b)
      end

      def prepare_rejected_log_export
        prepare_export('logs', representative_export('logs'))
        export_without_writable_disk
      end

      # The fixture rejects the last record of the second resource, after the
      # first resource and earlier records have already been inserted.
      def export_with_log_write_conflict
        with_log_database do |connection|
          @storage_snapshot_before = schema_data(connection)
          connection.query(File.read('fixtures/log_write_conflict.sql'))
        end
        begin
          @response = export_telemetry('logs', @payload)
          inspect_log_storage
        ensure
          with_log_database { |connection| connection.query('DROP INDEX log_write_conflict') }
        end
      end

      def export_duplicate_logs
        @responses = Array.new(2) { export_telemetry('logs', @payload) }
      end

      # Denying new files after startup exercises WAL creation at commit, while
      # leaving existing rows and the open database/log descriptors intact.
      def export_without_writable_disk
        with_log_database do |connection|
          connection.query('CHECKPOINT')
          @storage_snapshot_before = schema_data(connection)
        end
        with_unwritable_log_directory do
          @response = export_telemetry('logs', @payload)
          @failure_output = File.read('reports/server.log', nil, @receipt_offset)
        end
      end

      def with_unwritable_log_directory
        directory = File.dirname(Einblick.config.duckdb.path)
        permissions = File.stat(directory).mode & 0o777
        File.chmod(0o500, directory)
        yield
      ensure
        File.chmod(permissions, directory)
      end

      # Reset the disposable log schema/history, leaving unrelated data to
      # verify that initialization affects only the application's tables.
      def prepare_log_database
        Nonnative.stop
        log_database do |connection|
          connection.query(File.read('fixtures/log_schema.sql'))
        end
      end

      def initialize_log_database
        Nonnative.start
        with_log_database do |connection|
          @migration_result = connection.query(<<~SQL).to_a
            SELECT version, marker FROM goose_db_version CROSS JOIN log_migration_probe WHERE version = 1
          SQL
          connection.query('DROP TABLE log_migration_probe')
        end
      end
    end
  end
end
