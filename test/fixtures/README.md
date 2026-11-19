# 📥 OTLP source fixtures

`logs.json`, `metrics.json` and `traces.json` are synthetic, not captures of
deployed telemetry. The Ruby feature client sends them through upstream
generated OTLP messages over the existing gRPC listener, both uncompressed
and with gzip. The RSpec matcher reconstructs the printed protobuf request
and compares the complete message with what was sent. A fresh request marker
isolates each fixture export from previously appended receipts.

## 🔎 Sources and identity

The consumed source is go-service/v3 `v3.2.0`, pinned by `go.mod` and vendored
locally. It uses OTel API/SDK `v1.47.0` and OTLP protobuf `v1.11.1`.
`telemetry/attributes.NewResource` attaches `host.id`, `service.instance.id`,
`service.name`, `service.version` and `deployment.environment.name` under the
`1.43.0` semantic-convention schema. Arbitrary configured resource attributes
may also be present; these fixtures do not assume a namespace or Kubernetes
identity.

The fixed identities, nanosecond timestamps, trace/span IDs, typed nested
values and large integers are manufactured edge cases. No field is mapped
into storage in E-01. Protobuf JSON uses strings for 64-bit integers and base64
for bytes, including trace/span IDs. This is diagnostic Protobuf JSON, not an
OTLP/HTTP JSON endpoint.

## 📝 Logs

The pinned `telemetry/logger/otlp.go` uses the otelslog bridge `v0.21.0` and log
exporter `v0.23.0`. The bridge's scope name is the service name; go-service does
not configure a scope version. Correlated and uncorrelated records share the
request, with nested typed attributes and a large integer.
The first log body includes quotes, a newline and text resembling logger fields
to verify that the complete request remains intact inside the log message.

## 📊 Metrics

The pinned `telemetry/metrics/provider.go` registers runtime and host
instrumentation, and `reader.go` selects the OTLP reader/exporter.
The runtime instrumentation `v0.72.0` supplies the fixture's
`go.goroutine.count` gauge and `go.memory.allocations` cumulative monotonic sum.
The pinned gRPC instrumentation `v0.72.0` defaults to the newer RPC convention:
`rpc.server.call.duration` is a histogram in seconds. Its scope name and version
come from `otelgrpc/stats_handler.go` and `version.go`.

The fixture exercises these point shapes, start/collection nanoseconds, bucket
counts/bounds, typed attributes and a correlated exemplar. Values and buckets
are synthetic; receipt equality does not establish rate, aggregation, reset,
lookback or percentile correctness. Those remain later metric query work.

## 🔗 Traces

The pinned `telemetry/tracer/tracer.go` configures the exporter/provider with
the same resource identity. gRPC instrumentation uses the
`go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc`
scope at `v0.72.0`. The fixture includes two synthetic services sharing a trace,
parent/child IDs, span status, trace state, events, links and typed attributes.
It tests printing fidelity, not trace search or correlation queries.

## 🧪 Harness and architecture

The Ruby dependency `opentelemetry-exporter-otlp-common` `0.4.0` supplies upstream
generated messages under Apache-2.0. Dependencies are locked in
`test/Gemfile.lock`; none are linked into the Go server. `Einblick::OTLP` shares
the generic gRPC stub across the three services because the gem ships messages
without generated service stubs. Setup/actions live in `Einblick::OTLP::World`;
RSpec's `have_otlp_export` matcher compares the printed request. The existing
Cucumber/Nonnative lifecycle and configuration are reused.

Implementation conventions were checked against Bezeichner's
`internal/api/v1/transport/grpc/grpc.go` and Migrieren's module composition.
Einblick uses `internal/logs`, `internal/metrics` and `internal/traces`, with
logger-only `NewServer` constructors, direct `Register` functions and the shared
transport lifecycle. The upstream protobuf packages remain v1.

The local go-service checkout at `04f25241e9fe5390d0d51e88faf70c99e592582e`
was inspected alongside the consumed `v3.2.0` source; Bezeichner was at
`70bdb32ed3243aec8842b6107ed4de0de8a6da0b` and shared bin at
`00a890b21a01cfa4907262dfe19f9f2812b9e560`. Relevant framework paths include
`transport/grpc/module.go`, `transport/grpc/server.go`, `net/grpc/registrar.go`,
`telemetry/logger/module.go`, `telemetry/metrics/provider.go`,
`telemetry/tracer/tracer.go`, `telemetry/attributes/attributes.go` and
`encoding/proto/json.go`. The receivers reuse registrar, gzip, message-size
limit, rate limiter, logger and protobuf JSON encoder. They add no custom
record-count, output-size or concurrency limits. Larger log-batch/body cases
exercise requests previously rejected by the removed receiver thresholds;
message-size rejection remains owned by the shared transport.
