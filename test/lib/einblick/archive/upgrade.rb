# frozen_string_literal: true

module Einblick
  module Archive
    # Reopens version 4 work queues whose timestamps were written ahead of UTC.
    module World
      def stage_legacy_archive_batches
        stage_two_archive_batches
        restore_legacy_archive_metadata(File.basename(@earlier_archive, '.parquet'))
      end

      def restore_legacy_archive_metadata(blocked_id)
        Nonnative.stop
        log_database do |connection|
          connection.query(File.read('fixtures/drop_archive_retention_schema.sql'))
          shift_legacy_archive_timestamps(connection)
          seed_prior_archive_attempt(connection, blocked_id)
        end
      end

      def seed_prior_archive_attempt(connection, blocked_id)
        connection.query(<<~SQL, blocked_id)
          UPDATE log_archive_batches AS batch
          SET publication_attempted_at = CASE WHEN published_at IS NULL THEN prior_attempt.attempted_at END,
              eviction_attempted_at = CASE WHEN published_at IS NOT NULL THEN prior_attempt.attempted_at END
          FROM (
              SELECT max(coalesce(published_at, created_at)) + INTERVAL '1 second' AS attempted_at FROM log_archive_batches
          ) AS prior_attempt
          WHERE batch.id = ?::UUID
        SQL
      end

      def shift_legacy_archive_timestamps(connection)
        connection.query(<<~SQL)
          UPDATE log_archive_batches
          SET created_at = created_at + INTERVAL '9 hours',
              published_at = published_at + INTERVAL '9 hours',
              publication_attempted_at = publication_attempted_at + INTERVAL '9 hours',
              eviction_attempted_at = eviction_attempted_at + INTERVAL '9 hours'
        SQL
      end

      def evict_past_legacy_verification_failure
        @retained_archive_record_count = @query_record_count
        with_floci do
          publish_searchable_logs
          earlier_key = @floci.keys.fetch(0)
          publish_searchable_logs(query_fixture('log_queries'))
          reopen_legacy_eviction(earlier_key)
          inspect_eviction
          publish_after_upgrade
        end
      end

      def reopen_legacy_eviction(earlier_key)
        record_eviction_pair(earlier_key)
        @floci.replace_archive(earlier_key)
        restore_legacy_archive_metadata(@retained_batch_id)
        with_eviction_profile { observe_upgraded_eviction }
      end

      def observe_upgraded_eviction
        wait(timeout: 10).for { archive_diagnostics }.to include('local log archive eviction completed')
        wait(timeout: 10).for { archive_diagnostics }.to match(/local log archive eviction failed.*batch_id=#{@retained_batch_id}/)
        @eviction_retry_diagnostics = archive_diagnostics
        capture_legacy_archive_backlog
      end

      def capture_legacy_archive_backlog
        wait_for do
          @legacy_archive_metrics = Nonnative.observability.metrics.body
        end.to have_archive_backlog('pending_records' => 0)
      end

      def publish_after_upgrade
        publication_started = Time.now.to_i
        publish_searchable_logs(query_fixture('log_queries')) do
          @upgraded_publication_window = publication_started..Time.now.to_i
          wait(timeout: 10).for do
            @upgraded_archive_metrics = Nonnative.observability.metrics.body
          end.to have_archive_backlog('last_publication_timestamp_seconds' => be_positive)
        end
      end

      def search_after_legacy_archive_expiration
        with_floci do
          expired_key, = publish_expiring_archive_pair
          mark_legacy_archive(expired_key)
          with_eviction_profile('history_retention') { search_while_archive_expires(expired_key) }
          mark_legacy_archive(expired_key, publication_days_ago: 8)
          with_eviction_profile('history_retention') { query_logs }
        end
      end

      def mark_legacy_archive(key, publication_days_ago: 0)
        with_log_database do |connection|
          connection.query(<<~SQL, publication_days_ago, File.basename(key, '.parquet'))
            UPDATE log_archive_batches
            SET object_stored_at = NULL, published_at = published_at - to_days(?::INTEGER)
            WHERE id = ?::UUID AND evicted_at IS NOT NULL
          SQL
        end
      end
    end
  end
end
