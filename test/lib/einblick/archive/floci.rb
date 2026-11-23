# frozen_string_literal: true

module Einblick
  module Archive
    # Relays S3 requests to the disposable Floci bucket and simulates interruptions.
    class Floci
      include FlociFaults
      include FlociMultipart
      include FlociReads

      BUCKET = '/einblick-publication-feature'

      def start
        @server = Nonnative::HTTPServer.new(method(:forward), server_config)
        @server.start
        request('DELETE', BUCKET)
        response = request('PUT', BUCKET)
        raise "Could not create Floci bucket: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        @bucket_created = true
      end

      def stop
        restore
        @server&.stop
        return unless @bucket_created

        multipart_uploads.each do |key, upload_id|
          request('DELETE', "#{BUCKET}/#{key}?#{URI.encode_www_form(uploadId: upload_id)}")
        end
        keys.each { |key| request('DELETE', "#{BUCKET}/#{key}") }
        request('DELETE', BUCKET)
      end

      def multipart_uploads
        response = request('GET', "#{BUCKET}?uploads")
        raise "Could not list Floci multipart uploads: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        Nokogiri::XML(response.body).remove_namespaces!.css('Upload').map do |upload|
          [upload.at_css('Key').text, upload.at_css('UploadId').text]
        end
      end

      def keys
        response = request('GET', "#{BUCKET}?list-type=2")
        raise "Could not list Floci bucket: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        Nokogiri::XML(response.body).xpath('//*[local-name()="Key"]').map(&:text)
      end

      def download(key)
        response = request('GET', "#{BUCKET}/#{key}")
        raise "Could not read Floci object: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      end

      def delete_archive(key)
        response = request('DELETE', "#{BUCKET}/#{key}")
        raise "Could not delete Floci object: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      end

      def replace_archive(key, keep_checksum: false)
        bytes = download(key)
        original_checksum = Digest::SHA256.hexdigest(bytes)
        # Corrupt the Parquet footer so any attempt to read the replacement fails.
        changed_bytes(bytes, index: -1)
        checksum = keep_checksum ? original_checksum : Digest::SHA256.hexdigest(bytes)
        response = request('PUT', "#{BUCKET}/#{key}", bytes, 'x-amz-meta-sha256' => checksum)
        raise "Could not replace Floci object: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      end

      def upload_fixture(key, path, checksum)
        response = request('PUT', "#{BUCKET}/#{key}", File.binread(path), 'x-amz-meta-sha256' => checksum)
        raise "Could not seed Floci object: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      end

      private

      def server_config
        config = Nonnative::ConfigurationServer.new
        config.name = 'archive-floci'
        config.ports = [4567]
        config.log = 'reports/archive-floci.log'
        config
      end

      def request(method, path, body = nil, headers = {})
        http = Net::HTTP.new('127.0.0.1', Integer(ENV.fetch('EINBLICK_FLOCI_PORT', '4566')), nil)
        http.open_timeout = http.read_timeout = 2
        http.send_request(method, path, body, { 'Accept-Encoding' => 'identity' }.merge(headers))
      end

      def forward(env)
        incoming = Rack::Request.new(env)
        intercepted = intercept(incoming, env) || archive_listing_failure(incoming) || multipart_initiation_failure(incoming)
        return intercepted if intercepted

        listing = archive_listing?(incoming)
        @archive_listings = archive_listings + 1 if listing
        response = request(incoming.request_method, incoming.fullpath, payload(incoming), forward_headers(env))
        wait_on_archive_listing(incoming) if listing && response.is_a?(Net::HTTPSuccess)
        respond(incoming, response)
      end

      def rack_response(response, body)
        headers = response.to_hash.slice('content-type', 'content-length', 'content-range',
                                         'last-modified', 'etag', 'x-amz-meta-sha256')
        [response.code.to_i, headers.transform_values(&:first), [body]]
      end

      def payload(incoming)
        incoming.body.read if incoming.put? || incoming.post?
      end

      def forward_headers(env)
        names = %w[HOST AUTHORIZATION IF_NONE_MATCH IF_MATCH RANGE
                   X_AMZ_CONTENT_SHA256 X_AMZ_DATE X_AMZ_META_SHA256 X_AMZ_SECURITY_TOKEN]
        names.to_h { |name| [name.tr('_', '-'), env["HTTP_#{name}"]] }
             .merge('Content-Type' => env['CONTENT_TYPE']).compact
      end
    end
  end
end
