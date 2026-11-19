# frozen_string_literal: true

module Einblick
  # Standard OTLP clients for the existing feature-test server on localhost:12000.
  module OTLP
    SERVICES = {
      'logs' => {
        path: '/opentelemetry.proto.collector.logs.v1.LogsService/Export',
        request: Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceRequest,
        response: Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceResponse
      },
      'metrics' => {
        path: '/opentelemetry.proto.collector.metrics.v1.MetricsService/Export',
        request: Opentelemetry::Proto::Collector::Metrics::V1::ExportMetricsServiceRequest,
        response: Opentelemetry::Proto::Collector::Metrics::V1::ExportMetricsServiceResponse
      },
      'traces' => {
        path: '/opentelemetry.proto.collector.trace.v1.TraceService/Export',
        request: Opentelemetry::Proto::Collector::Trace::V1::ExportTraceServiceRequest,
        response: Opentelemetry::Proto::Collector::Trace::V1::ExportTraceServiceResponse
      }
    }.freeze

    class << self
      # Uses upstream messages with a generic stub because the upstream Ruby gem
      # ships message definitions without generated gRPC service stubs.
      def grpc(compression)
        @grpc ||= {}
        return @grpc[compression] if @grpc.key?(compression)

        algorithm = compression == 'none' ? :identity : compression.to_sym
        compression_options = GRPC::Core::CompressionOptions.new(default_algorithm: algorithm)
        channel_args = Einblick.user_agent.merge(compression_options.to_channel_arg_hash)

        @grpc[compression] = GRPC::ClientStub.new(
          'localhost:12000', :this_channel_is_insecure, channel_args: channel_args
        )
      end

      # Returns the upstream message used to build and serialize signal requests.
      def request_type(signal)
        SERVICES.fetch(signal).fetch(:request)
      end

      # Returns the upstream message expected from this signal's export RPC.
      def response_type(signal)
        SERVICES.fetch(signal).fetch(:response)
      end

      # Exports serialized protobuf bytes with a three-second deadline. Raw bytes
      # also let the feature harness exercise malformed requests.
      # Raises GRPC::BadStatus for a non-successful response.
      def export(signal, payload, compression: 'none')
        serialize = ->(request) { request }
        deserialize = response_type(signal).method(:decode)

        grpc(compression).request_response(
          SERVICES.fetch(signal).fetch(:path), payload, serialize, deserialize,
          deadline: Time.now + 3
        )
      end
    end
  end
end
