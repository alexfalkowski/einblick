# frozen_string_literal: true

module Einblick
  module Migrate
    # Migration actions use the same service launcher and stopped-file access as
    # log persistence scenarios. SQL fixtures affect only the disposable database.
    module World
      HISTORY_SQL = 'SELECT version FROM goose_db_version ORDER BY id'
      HISTORY_SNAPSHOT_SQL = 'SELECT id, version, applied_at FROM goose_db_version ORDER BY id'

      def migration_snapshot(connection)
        [schema_data(connection), connection.query(HISTORY_SNAPSHOT_SQL).to_a]
      end

      def reopen_current_schema
        with_log_database do |connection|
          @schema_data_before, @migration_history_before = migration_snapshot(connection)
        end
        with_log_database do |connection|
          @schema_data_after, @migration_history_after = migration_snapshot(connection)
        end
      end

      def attempt_future_migration
        Nonnative.stop
        change_schema_version(2, 3)
        log_database { |connection| @schema_data_before, @migration_history_before = migration_snapshot(connection) }
        attempt_database_start('server.yaml')
      ensure
        log_database { |connection| @schema_data_after, @migration_history_after = migration_snapshot(connection) }
        change_schema_version(3, 2)
        Nonnative.start
      end

      def prepare_previous_log_schema
        prepare_acknowledged_log_export
        Nonnative.stop
        log_database do |connection|
          connection.query(File.read('fixtures/drop_archive_schema.sql'))
          @schema_data_before, @migration_history_before = migration_snapshot(connection)
        end
      end

      def upgrade_log_schema
        Nonnative.start
        with_log_database do |connection|
          @schema_data_after = schema_data(connection)
          @migration_history = connection.query(HISTORY_SQL).to_a
        end
      end

      def retry_archive_migration
        log_database { |connection| connection.query("CREATE VIEW log_archive_rows AS SELECT 'preserved' AS marker") }
        attempt_database_start('server.yaml')
        inspect_failed_archive_migration
      ensure
        log_database { |connection| connection.query('DROP VIEW log_archive_rows') }
        upgrade_log_schema
      end

      def inspect_failed_archive_migration
        log_database do |connection|
          @failed_schema_tables = connection.query(<<~SQL).to_a
            SELECT table_name FROM information_schema.tables
            WHERE table_name IN ('log_archive_batches', 'log_archive_members', 'log_archive_uploads')
          SQL
          @failed_schema_sequences = connection.query(<<~SQL).to_a
            SELECT sequence_name FROM duckdb_sequences() WHERE sequence_name = 'log_archive_queue_order'
          SQL
          @failed_archive_schema_data, @failed_archive_history = migration_snapshot(connection)
        end
      end

      def change_schema_version(from, to)
        log_database { |connection| connection.query('UPDATE goose_db_version SET version = ? WHERE version = ?', to, from) }
      end

      def attempt_conflicting_migration
        Nonnative.stop
        log_database do |connection|
          connection.query(File.read('fixtures/log_schema.sql'))
          connection.query(File.read('fixtures/migration_conflict.sql'))
        end
        attempt_database_start('server.yaml')
        inspect_failed_migration
      ensure
        # Repair only the synthetic conflict and restart through the real
        # application, including when the failed-start attempt raises.
        log_database { |connection| connection.query('DROP TABLE logs') }
        Nonnative.start
      end

      def inspect_failed_migration
        log_database do |connection|
          @failed_schema_tables = connection.query(<<~SQL).to_a
            SELECT table_name FROM information_schema.tables
            WHERE table_schema = current_schema() AND table_name IN ('log_scopes', 'log_resources')
          SQL
          @failed_schema_sequences = connection.query("SELECT sequence_name FROM duckdb_sequences() WHERE sequence_name = 'log_id'").to_a
          @failed_migration_history = connection.query(HISTORY_SQL).to_a
          @failed_schema_conflict = connection.query('SELECT marker FROM logs').to_a
          @migration_probe = connection.query('SELECT marker FROM log_migration_probe').to_a
        end
      end

      def recover_conflicting_migration
        attempt_conflicting_migration
        inspect_migrated_database
        prepare_export('logs', representative_export('logs'))
        @response = export_telemetry('logs', @payload)
        inspect_log_storage
      end

      def inspect_migrated_database
        with_log_database do |connection|
          @schema_data_after = schema_data(connection)
          @migration_history = connection.query(HISTORY_SQL).to_a
          @migration_probe = connection.query('SELECT marker FROM log_migration_probe').to_a
          connection.query('DROP TABLE log_migration_probe')
        end
      end
    end
  end
end
