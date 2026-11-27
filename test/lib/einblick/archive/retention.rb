# frozen_string_literal: true

module Einblick
  module Archive
    HISTORY_RETENTION_SECONDS = 7 * 24 * 60 * 60

    # Searches archived logs while objects expire.
    module World
      def search_after_archive_expiration
        with_floci do
          expired_key, remaining_key = publish_expiring_archive_pair
          with_eviction_profile('history_retention') { search_after_archive_removal(expired_key) }
          with_eviction_profile { @retention_disabled_response = query_logs }
          @floci.delete_archive(remaining_key)
          with_eviction_profile('history_retention') { query_logs }
        end
      end

      def search_with_unknown_archive_age
        with_floci do
          expired_key, = publish_expiring_archive_pair
          clear_archive_object_age(expired_key)
          with_eviction_profile('history_retention') do
            search_while_archive_expires(expired_key)
            query_logs
          end
        end
      end

      def clear_archive_object_age(key)
        with_log_database do |connection|
          connection.query(<<~SQL, File.basename(key, '.parquet'))
            UPDATE log_archive_batches
            SET object_stored_at = NULL, published_at = published_at - INTERVAL '8 days'
            WHERE id = ?::UUID AND evicted_at IS NOT NULL
          SQL
        end
      end

      def search_after_expiration_listing_failure
        with_floci do
          expired_key, = publish_expiring_archive_pair
          with_eviction_profile('history_retention') do
            search_while_archive_expires(expired_key) { @floci.fail_next_archive_listing }
            @expiration_listing_diagnostics = archive_diagnostics
          end
        end
      end

      def search_after_younger_archive_loss
        with_floci do
          expired_key, younger_key = publish_expiring_archive_pair
          prepare_log_database
          initialize_log_database
          with_eviction_profile('history_retention') do
            listings = @floci.archive_listings
            search_while_archive_expires(expired_key) { @floci.delete_from_next_archive_listing(younger_key) }
            @loss_retry_listings = @floci.archive_listings - listings
          end
        end
      end

      def publish_expiring_archive_pair
        publish_searchable_logs
        first_key = @floci.keys.fetch(0)
        publish_searchable_logs(query_fixture('log_queries'))
        second_key = (@floci.keys - [first_key]).fetch(0)
        age_around_retention_cutoff(first_key, second_key)
        with_eviction_profile { wait_for_archive_evictions(first_key, second_key) }
        [first_key, second_key]
      end

      def age_around_retention_cutoff(expired_key, retained_key)
        hour = 3600
        cutoff = Time.now.utc - (168 * hour)
        @floci.set_archive_object_time(expired_key, cutoff - hour)
        @floci.set_archive_object_time(retained_key, cutoff + hour)
      end

      def search_after_archive_removal(expired_key)
        @logs_before_expiration = next_log_query_page('', page_size: 100).logs.to_a
        search_while_archive_expires(expired_key)
        @logs_after_expiration = next_log_query_page('', page_size: 100).logs.to_a
      end

      def search_while_archive_expires(expired_key)
        @floci.hold_archive_listing(expired_key)
        with_active_archive_query do
          wait_for { @floci.archive_listing_waiting? }.to be(true)
          @floci.delete_archive(expired_key)
          yield if block_given?
          @floci.release_archive_listing
        end
        @search_during_expiration = @grpc_response
      end
    end
  end
end
