# frozen_string_literal: true

module Einblick
  module Migrate
    # Builds the previous schema and exercises a failed publication migration.
    module World
      def prepare_staging_log_schema
        prepare_acknowledged_log_export
        Nonnative.stop
        log_database do |connection|
          connection.query(File.read('fixtures/drop_archive_retention_schema.sql'))
          connection.query(File.read('fixtures/drop_publication_schema.sql'))
          @schema_data_before, @migration_history_before = migration_snapshot(connection)
        end
      end

      def retry_publication_migration
        log_database { |connection| connection.query('CREATE TABLE log_archive_uploads (marker VARCHAR)') }
        attempt_database_start('server.yaml')
        inspect_failed_publication_migration
      ensure
        log_database { |connection| connection.query('DROP TABLE log_archive_uploads') }
        upgrade_log_schema
      end

      def inspect_failed_publication_migration
        log_database do |connection|
          @failed_publication_columns = connection.query(<<~SQL).to_a
            SELECT column_name FROM information_schema.columns
            WHERE table_name = 'log_archive_batches'
              AND column_name IN ('published_at', 'published_sha256', 'staging_cleaned_at', 'publication_attempted_at')
          SQL
          @failed_publication_snapshot = migration_snapshot(connection)
        end
      end
    end
  end
end
