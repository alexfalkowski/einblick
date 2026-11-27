# frozen_string_literal: true

require 'base64'
require 'digest/sha2'
require 'fileutils'
require 'json'
require 'net/http'
require 'open3'
require 'securerandom'
require 'yaml'
require 'uri'
require 'time'

require 'duckdb'
require 'nokogiri'
require 'opentelemetry/proto/collector/logs/v1/logs_service_pb'
require 'opentelemetry/proto/collector/metrics/v1/metrics_service_pb'
require 'opentelemetry/proto/collector/trace/v1/trace_service_pb'
require 'einblick/v1/service_services_pb'

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

require 'einblick/otlp'
require 'einblick/otlp/world'
require 'einblick/startup/world'
require 'einblick/logs/world'
require 'einblick/logs/exports'
require 'einblick/logs/http'
require 'einblick/logs/grpc'
require 'einblick/logs/queries'
require 'einblick/logs/query_times'
require 'einblick/logs/query_recovery'
require 'einblick/logs/query_load'
require 'einblick/migrate/world'
require 'einblick/archive/world'
require 'einblick/archive/fixtures'
require 'einblick/archive/inspection'
require 'einblick/archive/recovery'
require 'einblick/archive/startup'
require 'einblick/archive/floci_faults'
require 'einblick/archive/floci_multipart'
require 'einblick/archive/floci_reads'
require 'einblick/archive/floci'
require 'einblick/archive/publication'
require 'einblick/archive/publication_multipart'
require 'einblick/archive/history'
require 'einblick/archive/activity'
require 'einblick/archive/daily'
require 'einblick/archive/history_failures'
require 'einblick/archive/outage'
require 'einblick/archive/retention'
require 'einblick/archive/picker'
require 'einblick/archive/backlog'
require 'einblick/archive/eviction'
require 'einblick/archive/publication_recovery'
require 'einblick/archive/publication_scheduling'
require 'einblick/archive/digest_recovery'
require 'einblick/site/http'
require 'einblick/site/world'
require 'einblick/site/fixtures'
require 'einblick/site/refresh'
