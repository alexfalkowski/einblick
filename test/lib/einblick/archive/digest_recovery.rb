# frozen_string_literal: true

module Einblick
  module Archive
    # Fails the source read for one claimed day while the other day can publish.
    module World
      def recover_from_archive_digest_failure
        with_floci do
          with_archive_digest_fault do
            run_publication(query_local: false) { capture_progress_during_blocked_staging }
            with_log_database { |connection| inspect_batch_without_digest(connection) }
          end
          run_publication(query_local: false) { wait_for { @floci.keys }.to include(@blocked_staging_key) }
          inspect_recovered_digest_archive
        end
      end

      def with_archive_digest_fault
        with_log_database { |connection| connection.query(File.read('fixtures/block_archive_digest.sql')) }
        begin
          yield
        ensure
          with_log_database do |connection|
            connection.query('DROP VIEW log_archive_rows')
            connection.query('ALTER VIEW complete_log_archive_rows RENAME TO log_archive_rows')
          end
        end
      end

      def inspect_batch_without_digest(connection)
        @pending_archive_digest = connection.query(
          'SELECT content_sha256 FROM log_archive_batches WHERE id = ?::UUID', @blocked_staging_id
        ).to_a.fetch(0).first
        @pending_digest_members = connection.query(
          'SELECT log_id FROM log_archive_members WHERE batch_id = ?::UUID ORDER BY log_id', @blocked_staging_id
        ).to_a.flatten
      end

      def inspect_recovered_digest_archive
        path = File.join(WORKSPACE, 'recovered-digest.parquet')
        File.binwrite(path, @floci.download(@blocked_staging_key))
        with_log_database do |connection|
          @recovered_digest_members = connection.query(
            'SELECT log_id FROM read_parquet(?, hive_partitioning = false) ORDER BY log_id', path
          ).to_a.flatten
        end
      ensure
        FileUtils.rm_f(path)
      end
    end
  end
end
