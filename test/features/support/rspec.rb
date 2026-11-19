# frozen_string_literal: true

RSpec.configure do |config|
  config.wait_timeout = 3
end

RSpec::Matchers.define :have_otlp_export do |signal, request|
  match do |output|
    receipts = output.lines.grep(/OTLP #{signal} received/)
    next false unless receipts.one?

    # Text logging quotes payloads containing JSON strings; an empty {} is unquoted.
    payload = receipts.first[/payload=(.+?)(?= \w+=|\n|$)/, 1]
    payload = JSON.parse(payload) if payload.start_with?('"')
    actual = request.class.decode_json(payload)
    actual == request
  end

  failure_message do
    "expected exactly one OTLP #{signal} receipt matching the exported request"
  end
end
