# frozen_string_literal: true

module Einblick
  module Archive
    # Searches local logs during an outage and archive history after expiration.
    module World
      def search_local_logs_during_archive_outage
        with_floci do
          @floci.pause_access
          with_server_profile('publication') do
            open_local_log_searches
            read_local_log_pages
            capture_pending_archive_backlog
            capture_archive_backlog_recovery
          end
        end
      end

      def open_local_log_searches
        site = Einblick::Site::HTTP.new('http://localhost:11000')
        @archive_outage_view = site.open("/logs?#{URI.encode_www_form(@query)}", 'en')
        fallback = Nokogiri::HTML5(@archive_outage_view.body).at_css('.query-alert a[href*="search_scope=local"]')
        @local_fallback_view = site.open(fallback['href'], 'en')
        search = URI.encode_www_form(@query.merge('search_scope' => 'local', 'page_size' => 1))
        @local_logs_view = site.open("/logs?#{search}", 'en')
        @local_logs_next_view = site.open_next_page(@local_logs_view, 'en')
        @local_form_view = site.submit_log_form(@local_logs_view, 'en')
      end

      def read_local_log_pages
        scope = 'LOG_SEARCH_SCOPE_CURRENT_VOLUME'
        @local_logs_page = next_log_query_page('', page_size: 1, 'search_scope' => scope)
        token = @local_logs_page.next_page_token
        @local_logs_next_page = next_log_query_page(token, page_size: 1, 'search_scope' => scope)
        @changed_scope_response = query_logs(
          'search_scope' => 'LOG_SEARCH_SCOPE_ALL_SOURCES', 'page_size' => 1, 'page_token' => token
        )
        @invalid_scope_response = query_logs('search_scope' => 100)
        @oversized_token_response = query_logs('search_scope' => scope, 'page_size' => 1, 'page_token' => padded_page_token(token))
      end

      def padded_page_token(token)
        json = Base64.urlsafe_decode64(token)
        Base64.urlsafe_encode64(json + (' ' * json.bytesize), padding: false)
      end

      def search_after_archive_expiration
        with_floci do
          expired_key, remaining_key = publish_expiring_archive_pair
          with_eviction_profile('history_retention') { search_after_archive_removal(expired_key) }
          with_eviction_profile { @retention_disabled_response = query_logs }
          @floci.delete_archive(remaining_key)
          with_eviction_profile('history_retention') { query_logs }
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
