# frozen_string_literal: true

Given('a representative local {word} export') do |signal|
  signal = "#{signal}s"
  prepare_export(signal, representative_export(signal))
end

Given('an empty {word} export') do |signal|
  signal = "#{signal}s"
  prepare_export(signal, Einblick::OTLP.request_type(signal).new)
end

Given('a malformed {word} export') do |signal|
  signal = "#{signal}s"
  prepare_export(signal, Einblick::OTLP.request_type(signal).new)
  @payload = "\xff".b
end

When('the client exports {word} using {string} compression') do |signal, compression|
  @response = export_telemetry(signal, @payload, compression: compression)
end

When('a valid empty export follows') do
  prepare_export(@signal, Einblick::OTLP.request_type(@signal).new)
  @response = export_telemetry(@signal, @payload)
end

Then('the {word} export should succeed without partial success') do |signal|
  expect(@response).to be_a(Einblick::OTLP.response_type("#{signal}s"))
  expect(@response.partial_success).to be_nil
end

Then('the server should print the complete {word} export') do |signal|
  output = File.read('reports/server.log', nil, @receipt_offset)
  expect(output).to have_otlp_export("#{signal}s", @request)
end

Then('the server should not print telemetry for this export') do
  expect(File.read('reports/server.log', nil, @receipt_offset)).not_to have_otlp_export(@signal)
end

Then('the {word} export should fail with {string}') do |_signal, status|
  expect(@response).to be_a(GRPC::BadStatus)
  expect(@response.code).to eq(GRPC::Core::StatusCodes.const_get(status))
end
