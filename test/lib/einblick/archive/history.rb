# frozen_string_literal: true

module Einblick
  module Archive
    # Runs historical investigations using the same HTTP query and archive worker.
    module World
      def prepare_paged_archive_query
        prepare_archive_storage
        prepare_searchable_logs
        prepare_first_log_page
      end

      def continue_across_eviction
        with_floci do
          publish_searchable_logs { collect_log_pages(@first_log_page) }
          @overlap_query_logs = @query_logs
          with_archive_eviction { collect_log_pages(@first_log_page) }
          inspect_eviction
        end
      end

      def query_during_archive_eviction
        with_floci do
          publish_searchable_logs
          archived_key = @floci.keys.fetch(0)
          with_archive_eviction
          publish_searchable_logs(query_fixture('log_queries'))
          local_key = (@floci.keys - [archived_key]).fetch(0)
          @floci.hold_archive_read(local_key)
          @floci.hold_archive_read(archived_key)
          with_eviction_profile { query_while_evicting(archived_key, local_key) }
        end
      end

      def query_while_evicting(archived_key, local_key)
        with_active_archive_query do
          wait_for { @floci.archive_read_waiting?(archived_key) }.to be(true)
          @floci.release_archive_read(local_key)
          wait_for_archive_evictions(local_key)
          @floci.release_archive_read(archived_key)
        end
      end

      def query_fresh_archive(failure: false)
        query_from_fresh_archive do
          @floci.pause_access if failure
          query_logs
        end
      end

      def query_duplicate_archive_ids
        @foreign_receipt_windows = @query_receipt_windows.dup
        with_fresh_archive do
          publish_searchable_logs(query_fixture('log_queries')) do
            @first_log_page = next_log_query_page('', page_size: 1)
            collect_matching_id_pages
            @logs_before_eviction = @query_logs
          end
          with_archive_eviction { collect_matching_id_pages }
        end
      end

      def collect_matching_id_pages
        identity = ->(log) { [log.id, log.receive_time.seconds, log.receive_time.nanos] }
        collect_log_pages(@first_log_page, page_size: 1, identity: identity)
      end

      def with_active_archive_query
        operation = grpc_log_query_operation(@query, deadline: Time.now + 30)
        pending = Thread.new { execute_grpc_query(operation) }
        yield operation
        @grpc_response = pending.value
      ensure
        operation&.cancel
        @floci.release_archive_read
        @floci.release_archive_listing
        pending&.join
      end

      def query_from_fresh_archive(&)
        with_fresh_archive { with_server_profile('publication', &) }
      end

      def with_fresh_archive
        with_floci do
          publish_searchable_logs
          @original_archive_objects = remote_archive_checksums
          prepare_log_database
          initialize_log_database
          yield
          @floci.restore
          @discovered_archive_objects = remote_archive_checksums
        end
      end

      def publish_searchable_logs(request = nil)
        @archive_offset = File.size('reports/server.log')
        with_server_profile('publication') do
          acknowledge_query_export(request) if request
          wait_for { archive_diagnostics }.to include('remote log archive publication completed')
          yield if block_given?
        end
      end
    end
  end
end
