# frozen_string_literal: true

module Einblick
  module Archive
    # Exercises archive workspace preparation through normal service startup.
    module World
      def prepare_public_archive_directory
        prepare_archive_storage
        File.chmod(0o755, ARCHIVE_DIRECTORY)
      end

      def inspect_archive_directory_at_startup
        with_server_profile('archive') { @archive_directory_mode = File.stat(ARCHIVE_DIRECTORY).mode & 0o777 }
      end

      def prepare_missing_archive_workspace
        FileUtils.rm_rf(WORKSPACE)
        FileUtils.mkdir_p(File.dirname(WORKSPACE))
      end

      def prepare_unwritable_archive_workspace
        prepare_archive_storage(create_export_directory: false)
        File.chmod(0o500, WORKSPACE)
      end

      def attempt_archive_start
        Nonnative.stop
        attempt_database_start('archive.yaml')
      ensure
        Nonnative.start
      end
    end
  end
end
