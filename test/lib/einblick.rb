# frozen_string_literal: true

require 'securerandom'
require 'yaml'
require 'base64'

module Einblick
  class << self
    def config
      @config ||= Nonnative::ConfigurationFile.load('.config/server.yaml')
    end

    def health_grpc
      @health_grpc ||= Nonnative.grpc_health(host: 'localhost', port: 12_000, service: 'einblick')
    end

    def user_agent
      @user_agent ||= Nonnative::Header.grpc_user_agent('Einblick-ruby-client/1.0 gRPC/1.0')
    end
  end
end
