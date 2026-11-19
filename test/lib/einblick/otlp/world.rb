# frozen_string_literal: true

module Einblick
  module OTLP
    # Request setup and actions shared by the telemetry feature scenarios.
    module World
      # Gives each synthetic fixture a fresh request marker in the printed output.
      def representative_export(signal)
        fixture = File.read("fixtures/#{signal}.json").gsub('fixture-request', SecureRandom.uuid)
        Einblick::OTLP.request_type(signal).decode_json(fixture)
      end

      # Captures the expected request and the start of its server output.
      def prepare_export(signal, request)
        @signal = signal
        @request = request
        @payload = request.class.encode(request)
        @receipt_offset = File.size('reports/server.log')
      end

      # Returns the response or gRPC failure for scenario assertions.
      def export_telemetry(signal, payload, **)
        Einblick::OTLP.export(signal, payload, **)
      rescue GRPC::BadStatus => e
        e
      end
    end
  end
end
