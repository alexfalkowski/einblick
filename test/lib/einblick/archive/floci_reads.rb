# frozen_string_literal: true

module Einblick
  module Archive
    # Holds selected remote reads while the real worker or caller advances.
    module FlociReads
      def archive_listings
        @archive_listings.to_i
      end

      def fail_next_archive_listing
        @mode = :fail_next_archive_listing
      end

      def delete_from_next_archive_listing(key)
        @delete_on_listing = key
      end

      def set_archive_object_time(key, stored_at)
        @archive_object_times ||= {}
        @archive_object_times[key] = stored_at
      end

      def hold_archive_listing(key)
        @archive_listing_prefix = "#{File.dirname(key)}/"
        @archive_listing_gate = Queue.new
      end

      def archive_listing_waiting?
        @archive_listing_gate&.num_waiting == 1
      end

      def release_archive_listing
        @archive_listing_gate&.close
        @archive_listing_gate = nil
      end

      def hold_archive_read(key)
        @archive_read_gates ||= {}
        @archive_read_gates[key] = Queue.new
      end

      def archive_read_waiting?(key, minimum: 1)
        @archive_read_gates&.fetch(key, nil)&.num_waiting.to_i >= minimum
      end

      def release_archive_read(key = nil)
        return unless @archive_read_gates

        if key
          @archive_read_gates.delete(key)&.close
        else
          @archive_read_gates.each_value(&:close)
          @archive_read_gates.clear
        end
      end

      private

      def archive_listing_failure(incoming)
        return unless archive_listing?(incoming)

        if @delete_on_listing
          key = @delete_on_listing
          @delete_on_listing = nil
          delete_archive(key)
        end
        return unless @mode == :fail_next_archive_listing

        @mode = nil
        [503, {}, []]
      end

      def archive_listing?(incoming)
        incoming.get? && incoming.path_info == Floci::BUCKET && incoming.GET['list-type'] == '2'
      end

      def wait_on_archive_listing(incoming)
        @archive_listing_gate&.pop if incoming.GET['prefix'] == @archive_listing_prefix
      end

      def archive_listing_response(incoming, response)
        wait_on_archive_listing(incoming)
        return respond(incoming, response) unless @archive_object_times

        body = archive_listing_body(response.body)
        rack_response(response, body).tap { |_, headers, _| headers['content-length'] = body.bytesize.to_s }
      end

      def archive_listing_body(body)
        document = Nokogiri::XML(body)
        document.xpath('//*[local-name()="Contents"]').each do |object|
          key = object.at_xpath('./*[local-name()="Key"]').text
          stored_at = @archive_object_times[key]
          object.at_xpath('./*[local-name()="LastModified"]').content = stored_at.iso8601 if stored_at
        end
        document.to_xml
      end

      def archive_object_response(incoming, response, body)
        record_archive_verification(incoming, response)
        rack_response(response, body).tap do |_, headers, _|
          stored_at = @archive_object_times&.[](archive_key(incoming))
          headers['last-modified'] = stored_at.httpdate if stored_at && response.is_a?(Net::HTTPSuccess)
        end
      end

      def record_archive_verification(incoming, response)
        return unless response.is_a?(Net::HTTPSuccess) && archive_verification?(incoming) && @mode != :corrupt_verification

        (@verified_archives ||= {})[archive_key(incoming)] = true
      end

      def archive_eviction_failure(incoming)
        return unless @defer_archive_eviction && archive_verification?(incoming) && @verified_archives&.key?(archive_key(incoming))

        [412, {}, []]
      end

      # The worker verifies the full object with If-Match. DuckDB requests ranges.
      def archive_verification?(incoming)
        incoming.get? && incoming.get_header('HTTP_IF_MATCH') && !incoming.get_header('HTTP_RANGE')
      end

      def intercept_archive_read(incoming)
        return unless incoming.head? || incoming.get?

        key = archive_key(incoming)
        return [403, {}, []] if @unreadable_archives&.include?(key)

        @archive_read_gates&.[](key)&.pop
      end

      def archive_key(incoming)
        URI::DEFAULT_PARSER.unescape(incoming.path_info).delete_prefix("#{Floci::BUCKET}/")
      end
    end
  end
end
