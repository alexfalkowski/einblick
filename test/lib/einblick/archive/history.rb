# frozen_string_literal: true

module Einblick
  module Archive
    # Runs historical investigations using the same HTTP query and archive worker.
    module World
      def prepare_paged_archive_query
        prepare_archive_storage
        prepare_searchable_logs
        age_pending_archive_receipts
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
          page_through_archived_logs unless failure
        end
      end

      def page_through_archived_logs
        site = Einblick::Site::HTTP.new('http://localhost:11000')
        first = site.submit('/logs', @query.merge('page_size' => 1), 'en')
        next_page = Nokogiri::HTML5.fragment(first.body).at_css('a.next')['hx-put']
        @archive_next_page = site.submit(next_page, {}, 'en')
      end

      def query_duplicate_archive_ids
        with_fresh_archive do
          @foreign_receipt_windows = @query_receipt_windows.dup
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
        acknowledge_query_export(request) if request
        age_pending_archive_receipts
        @archive_offset = File.size('reports/server.log')
        with_publication_profile do
          wait_for_publication
          yield if block_given?
        end
      end
    end
  end
end
