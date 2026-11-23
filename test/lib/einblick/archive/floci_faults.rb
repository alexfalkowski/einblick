# frozen_string_literal: true

module Einblick
  module Archive
    # Controls the existing Floci relay at the object-store boundary.
    module FlociFaults
      attr_reader :attempted_checksums, :competing_checksum

      def lose_acknowledgement
        @acknowledgement_gate = Queue.new
        @mode = :lose_acknowledgement
      end

      def acknowledgement_waiting?
        @acknowledgement_gate&.num_waiting == 1
      end

      def release_acknowledgement
        @acknowledgement_gate&.close
        @acknowledgement_gate = nil
      end

      def pause_access
        @mode = :unavailable
      end

      def corrupt_verification
        @mode = :corrupt_verification
      end

      def defer_commit
        @mode = :defer_commit
        @attempted_checksums = []
      end

      def commit_on_retry
        @mode = :commit_on_retry
      end

      def compete_on_completion(path, metadata)
        @competing_bytes = changed_bytes(File.binread(path))
        @competing_checksum = Digest::SHA256.hexdigest(@competing_bytes)
        @competing_metadata = metadata == 'attempted' ? Digest::SHA256.file(path).hexdigest : @competing_checksum
        @mode = :compete_on_completion
      end

      def restore
        release_acknowledgement
        release_archive_read
        release_archive_listing
        @part_gate&.close
        @part_gate = nil
        @mode = nil
      end

      def hold_upload_parts
        @part_gate = Queue.new
      end

      def upload_part_waiting?
        @upload_part_waiting == true
      end

      private

      def intercept(incoming, env)
        wait_on_archive_read(incoming)
        return [503, {}, []] if @mode == :unavailable || wait_on_part?(incoming)
        return unless commit_request?(incoming)

        case @mode
        when :defer_commit then save_commit(incoming, env)
        when :commit_on_retry then send_deferred_commit(env)
        when :compete_on_completion then insert_competing_object(incoming)
        end
      end

      def save_commit(incoming, env)
        @deferred_write = [incoming.request_method, incoming.fullpath, payload(incoming), forward_headers(env)]
        @attempted_checksums << env.fetch('HTTP_X_AMZ_META_SHA256')
        pause_access
        [502, {}, []]
      end

      def send_deferred_commit(env)
        @attempted_checksums << env.fetch('HTTP_X_AMZ_META_SHA256')
        response = request(*@deferred_write)
        raise "Could not commit original Floci upload: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        @mode = nil
      end

      def insert_competing_object(incoming)
        return unless incoming.post?

        path = incoming.fullpath.split('?', 2).first
        response = request('PUT', path, @competing_bytes, 'x-amz-meta-sha256' => @competing_metadata)
        raise "Could not commit competing Floci object: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        @mode = nil
      end

      def wait_on_part?(incoming)
        gate = @part_gate
        return false unless gate && incoming.put? && incoming.GET.key?('partNumber')

        @upload_part_waiting = true
        gate.pop
        true
      end

      def commit_request?(incoming)
        incoming.GET.key?('uploadId') ? incoming.post? : incoming.put?
      end

      def respond(incoming, response)
        if @mode == :lose_acknowledgement && commit_request?(incoming) && response.is_a?(Net::HTTPSuccess)
          gate = @acknowledgement_gate
          pause_access
          gate.pop
          return [502, {}, []]
        end

        body = response.body.to_s
        body = changed_bytes(body) if @mode == :corrupt_verification && incoming.get? && response.is_a?(Net::HTTPSuccess)
        archive_object_response(incoming, response, body)
      end

      def changed_bytes(bytes, index: 0)
        bytes.setbyte(index, bytes.getbyte(index) ^ 1)
        bytes
      end
    end
  end
end
