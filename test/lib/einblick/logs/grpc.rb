# frozen_string_literal: true

module Einblick
  module Logs
    # Generated clients exercise the same query operation through gRPC.
    module World
      def query_grpc_logs(overrides = {})
        @grpc_response = execute_grpc_query(grpc_log_query_operation(@query.merge(overrides)))
      end

      def execute_grpc_query(operation)
        operation.execute
      rescue GRPC::BadStatus => e
        e
      end

      def grpc_log_query_operation(query, deadline: Time.now + 3)
        client = Einblick::V1::Service::Stub.new('localhost:12000', :this_channel_is_insecure, channel_args: Einblick.user_agent)
        request = Einblick::V1::ListLogsRequest.decode_json(JSON.generate(query))
        @query_request_id = SecureRandom.uuid
        client.list_logs(request, deadline: deadline, metadata: { 'request-id' => @query_request_id }, return_op: true)
      end

      def continue_logs_using_grpc(first_page = @first_log_page, page_size: 2)
        collect_log_pages(first_page) do |token|
          query_grpc_logs('page_size' => page_size, 'page_token' => token)
          raise "query failed: #{@grpc_response}" unless @grpc_response.is_a?(Einblick::V1::ListLogsResponse)

          @grpc_response
        end
      end

      def prepare_large_text_filter_logs
        @query['text'] = 'x' * (500 * 1024)
        @large_query_requests = [QUERY_TIME + 1, QUERY_TIME].map { |timestamp| large_text_query_export(timestamp) }
        @expected_query_records = @large_query_requests.flat_map { |request| log_query_records(request) }
        @large_query_responses = @large_query_requests.map do |request|
          acknowledge_query_export(request)
          @response
        end
      end

      def large_text_query_export(timestamp)
        request = query_fixture('log_query_times')
        records = request.resource_logs.first.scope_logs.first.log_records
        records.replace([records.first])
        records.first.time_unix_nano = timestamp
        records.first.body.string_value = @query['text']
        request
      end

      def query_large_text_filter_pages
        query_grpc_logs('page_size' => 1)
        raise "query failed: #{@grpc_response}" unless @grpc_response.is_a?(Einblick::V1::ListLogsResponse)

        continue_logs_using_grpc(@grpc_response, page_size: 1)
      end

      def query_grpc_with_expired_budget
        with_query_profile('query_timeout') { query_grpc_logs }
      end

      def cancel_active_grpc_query
        operation = grpc_log_query_operation(@heavy_query, deadline: Time.now + 30)
        client = Thread.new { execute_grpc_query(operation) }
        wait_for_log_query_limit(1)
        operation.cancel
        # The existing RSpec wait budget is shorter than the cancellation profile's server budget.
        wait_for_log_query_limit(0)
        @grpc_response = client.value
      ensure
        operation&.cancel
        client&.join
      end
    end
  end
end
