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
        stage_log_archive(@archive_request, 1)
        with_floci do
          key = hold_staged_archive
          @floci.fail_next_archive_listing
          run_publication('publication_breaker', query_local: false) do
            query_during_archive_recovery
            @floci.release_archive_read(key)
          end
          inspect_publication
        end
      end

      def query_across_stale_listing
        with_floci do
          publish_searchable_logs
          archived_key = @floci.keys.fetch(0)
          with_archive_eviction
          stage_log_archive(query_fixture('log_queries'), 1)
          later_key = hold_staged_archive
          @floci.hold_archive_listing(archived_key)
          with_eviction_profile { publish_after_archive_listing(later_key) }
        end
      end

      def publish_after_archive_listing(later_key)
        with_active_archive_query do
          wait_for { @floci.archive_listing_waiting? }.to be(true)
          @floci.release_archive_read(later_key)
          wait_for_archive_evictions(later_key)
          @floci.release_archive_listing
        end
      end

      def query_after_archive_cancellation
        query_from_fresh_archive do
          prepare_local_logs_during_archive_stall
          archived_key = @original_archive_objects.keys.fetch(0)
          cancel_while_reading_archive(archived_key)
          wait_for_log_query_limit(0)
          query_logs
        end
      end

      def cancel_while_reading_archive(key)
        @floci.hold_archive_read(key)
        with_active_archive_query do |operation|
          with_active_archive_query do
            wait_for { @floci.archive_read_waiting?(key, minimum: 2) }.to be(true)
            search_local_logs_during_archive_stall(key)
            operation.cancel
            search_while_cancelled_archive_query_drains
            @floci.release_archive_read(key)
          end
        end
      end

      def prepare_local_logs_during_archive_stall
        @local_stall_service = "local-#{@query_service}"
        @local_stall_request = query_fixture('log_queries', service: @local_stall_service)
        @local_stall_bounds = move_logs_to_recent_window(@local_stall_request)
        archive_receipts = @query_receipt_windows.dup
        export_query_logs(@local_stall_request, @local_stall_request.class.encode(@local_stall_request))
        @local_stall_receipts = @query_receipt_windows
        @query_receipt_windows = archive_receipts
        records = log_query_records(@local_stall_request)
        @local_stall_records = [5, 4, 3, 2, 1].map { |index| records[index] }
      end

      def search_local_logs_during_archive_stall(key)
        @local_stall_response = query_logs(@local_stall_bounds.merge('service' => @local_stall_service))
        @archive_read_remained_held = @floci.archive_read_waiting?(key)
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
