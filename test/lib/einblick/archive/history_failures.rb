# frozen_string_literal: true

module Einblick
  module Archive
    # Exercises history queries when an archive listing or read is interrupted.
    module World
      def query_after_archive_listing_failure
        query_from_fresh_archive do
          @floci.fail_next_archive_listing
          query_logs
        end
      end

      def publish_while_archive_listings_are_unavailable
        with_floci do
          @floci.fail_next_archive_listing
          run_publication('publication_breaker') do
            query_during_archive_recovery
            acknowledge_archive_logs(@archive_request)
          end
          inspect_publication
        end
      end

      def query_across_stale_listing
        with_floci do
          publish_searchable_logs
          archived_key = @floci.keys.fetch(0)
          with_archive_eviction
          @floci.hold_archive_listing(archived_key)
          with_eviction_profile { publish_after_archive_listing(archived_key) }
        end
      end

      def publish_after_archive_listing(archived_key)
        with_active_archive_query do
          wait_for { @floci.archive_listing_waiting? }.to be(true)
          acknowledge_query_export(query_fixture('log_queries'))
          later_keys = []
          wait_for { later_keys = @floci.keys - [archived_key] }.not_to be_empty
          wait_for_archive_evictions(*later_keys)
          @floci.release_archive_listing
        end
      end

      def query_after_archive_cancellation
        query_from_fresh_archive do
          cancel_while_reading_archive(@floci.keys.fetch(0))
          query_logs
        end
      end

      def cancel_while_reading_archive(key)
        @floci.hold_archive_read(key)
        with_active_archive_query do |operation|
          wait_for { @floci.archive_read_waiting?(key) }.to be(true)
          operation.cancel
          search_while_cancelled_archive_query_drains
          wait_for_log_query_limit(1)
          @floci.release_archive_read(key)
          wait_for_log_query_limit(0)
        end
      end

      def search_while_cancelled_archive_query_drains
        listings = @floci.archive_listings
        operation = grpc_log_query_operation(@query)
        @queued_archive_response = execute_grpc_query(operation)
        # The server diagnostic confirms the probe reached the repository.
        wait_for { archive_diagnostics }.to match(/log query failed.*request_id=#{@query_request_id}/)
        @listings_while_archive_query_drained = @floci.archive_listings - listings
      end

      def query_after_archive_loss
        with_floci do
          publish_searchable_logs
          missing_key = @floci.keys.fetch(0)
          publish_searchable_logs(query_fixture('log_queries'))
          keys = @floci.keys
          with_eviction_profile do
            wait_for_archive_evictions(*keys)
            search_after_removing_archived_object(missing_key)
          end
        end
      end

      def search_after_removing_archived_object(key)
        @logs_before_archive_loss = next_log_query_page('', page_size: 100).logs
        @floci.delete_archive(key)
        @available_archive_keys = @floci.keys
        query_logs
      end
    end
  end
end
