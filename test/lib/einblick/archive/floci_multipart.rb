# frozen_string_literal: true

module Einblick
  module Archive
    # Rejects multipart initiation and observes the next attempt at the S3 boundary.
    module FlociMultipart
      attr_reader :multipart_recovery_requests

      def fail_next_multipart_initiation
        @mode = :fail_next_multipart_initiation
        @multipart_recovery_requests = []
      end

      private

      def multipart_initiation_failure(incoming)
        return unless @mode == :fail_next_multipart_initiation

        if incoming.post? && incoming.GET.key?('uploads')
          return reject_multipart_initiation(incoming) unless @rejected_multipart_path

          @multipart_recovery_requests << incoming.request_method
          @mode = nil
        elsif incoming.head? && incoming.path_info == @rejected_multipart_path
          @multipart_recovery_requests << incoming.request_method
        end
        nil
      end

      def reject_multipart_initiation(incoming)
        @rejected_multipart_path = incoming.path_info
        [503, {}, []]
      end
    end
  end
end
