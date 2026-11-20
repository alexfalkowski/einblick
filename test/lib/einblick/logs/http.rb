# frozen_string_literal: true

module Einblick
  module Logs
    # Sends protobuf JSON to the same versioned method as the generated gRPC client.
    class HTTP < Nonnative::HTTPClient
      def list(query)
        post('einblick.v1.Service/ListLogs', JSON.generate(query),
             headers: { accept: 'application/pbjson', content_type: 'application/pbjson',
                        user_agent: 'Einblick-ruby-client/1.0 HTTP/1.0' },
             read_timeout: 10, open_timeout: 10)
      end
    end
  end
end
