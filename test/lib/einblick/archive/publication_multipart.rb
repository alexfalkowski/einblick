# frozen_string_literal: true

module Einblick
  module Archive
    # Drives recovery from failures during multipart publication.
    module World
      def recover_interrupted_multipart_publication
        with_floci do
          stop_during_multipart_upload
          @uploads_after_stop = @floci.multipart_uploads
          @objects_after_stop = @floci.keys
          @staging_after_stop = archive_files
          @floci.restore
          run_publication
          inspect_publication
        end
      end

      def recover_failed_multipart_initiation
        with_floci do
          @floci.fail_next_multipart_initiation
          run_publication
          @multipart_recovery_requests = @floci.multipart_recovery_requests
          inspect_publication
        end
      end

      def stop_during_multipart_upload
        @floci.hold_upload_parts
        with_server_profile('publication') do
          wait_for { @floci.upload_part_waiting? }.to be(true)
          @uploads_before_stop = @floci.multipart_uploads
        end
      end
    end
  end
end
