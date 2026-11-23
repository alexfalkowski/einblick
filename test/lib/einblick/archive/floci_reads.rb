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

      def archive_read_waiting?(key)
        @archive_read_gates&.fetch(key, nil)&.num_waiting.to_i.positive?
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
        return unless @mode == :fail_next_archive_listing && archive_listing?(incoming)

        @mode = nil
        [503, {}, []]
      end

      def archive_listing?(incoming)
        incoming.get? && incoming.path_info == Floci::BUCKET && incoming.GET['list-type'] == '2'
      end

      def wait_on_archive_listing(incoming)
        @archive_listing_gate&.pop if incoming.GET['prefix'] == @archive_listing_prefix
      end

      def wait_on_archive_read(incoming)
        return unless @archive_read_gates && (incoming.head? || incoming.get?)

        key = URI::DEFAULT_PARSER.unescape(incoming.path_info).delete_prefix("#{Floci::BUCKET}/")
        @archive_read_gates[key]&.pop
      end
    end
  end
end
