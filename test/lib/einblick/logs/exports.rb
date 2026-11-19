# frozen_string_literal: true

module Einblick
  module Logs
    # Export preparation shares the storage scenarios' existing World and client.
    module World
      def prepare_acknowledged_log_export
        prepare_log_database
        initialize_log_database
        request = representative_export('logs')
        # Distinct timestamps keep these rows valid under the failure fixture's index.
        request.resource_logs.first.scope_logs.first.log_records.each_with_index do |record, index|
          record.time_unix_nano += index
        end
        prepare_export('logs', request)
        @response = export_telemetry('logs', @payload)
        inspect_log_storage
      end

      def prepare_record_free_log_export(context)
        request = Einblick::OTLP.request_type('logs').new
        request = request.class.decode_json(File.read('fixtures/log_empty_contexts.json')) if context == 'resource and scope context'
        with_log_database { |connection| @storage_snapshot_before = schema_data(connection) }
        prepare_export('logs', request)
      end

      def prepare_conflicting_log_export
        request = Einblick::OTLP.request_type('logs').decode_json(File.read('fixtures/log_write_conflict.json'))
        prepare_export('logs', request)
      end

      def prepare_log_times(timestamp, observed)
        request = representative_export('logs')
        record = request.resource_logs.first.scope_logs.first.log_records.first
        record.time_unix_nano = timestamp
        record.observed_time_unix_nano = observed
        prepare_export('logs', request)
      end

      def prepare_log_bodies
        request = representative_export('logs')
        bodies = Einblick::OTLP.request_type('logs').decode_json(File.read('fixtures/log_body_types.json'))
        request.resource_logs.concat(bodies.resource_logs.to_a)
        with_log_database { |connection| @storage_snapshot_before = schema_data(connection) }
        prepare_export('logs', request)
      end
    end
  end
end
