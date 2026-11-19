# frozen_string_literal: true

RSpec.configure do |config|
  config.wait_timeout = 3
end

RSpec::Matchers.define :have_otlp_export do |signal, request|
  match do |output|
    receipts = output.lines.filter_map do |line|
      fields = line.scan(/(?:\A|\s)([\w.]+)=("(?:\\.|[^"\\])*"|\S+)/).to_h
      fields if fields['signal'] == signal
    end
    next receipts.any? unless request
    next false unless receipts.one?
    next false if receipts.first.key?('payload')

    # The complete request is the message; slog leaves the empty {} unquoted.
    payload = receipts.first['msg']
    next false unless payload

    payload = JSON.parse(payload) if payload.start_with?('"')
    actual = request.class.decode_json(payload)
    actual == request
  end

  failure_message do
    if request
      "expected exactly one OTLP #{signal} message matching the exported request, without a payload field"
    else
      "expected an OTLP #{signal} receipt"
    end
  end
end
