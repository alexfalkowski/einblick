# 📥 OTLP source fixtures

`logs.json`, `metrics.json` and `traces.json` are synthetic, not captures of
deployed telemetry. The Ruby feature client sends them through upstream
generated OTLP messages over the existing gRPC listener, both uncompressed
and with gzip. RSpec matchers compare complete stored log resource/scope/record
messages and reconstruct printed metric/trace requests. A fresh marker isolates
each export; storage inspection also selects its server receipt range.

## 🔎 Sources and identity

The consumed source is go-service/v3 `v3.2.0`, pinned by `go.mod` and vendored
locally. It uses OTel API/SDK `v1.47.0` and OTLP protobuf `v1.11.1`.
`telemetry/attributes.NewResource` attaches `host.id`, `service.instance.id`,
`service.name`, `service.version` and `deployment.environment.name` under the
`1.43.0` semantic-convention schema. Arbitrary configured resource attributes
may also be present; these fixtures do not assume a namespace or Kubernetes
identity.

The fixed identities, nanosecond timestamps, trace/span IDs, typed nested
values and large integers are manufactured edge cases. Protobuf JSON uses
strings for 64-bit integers and base64
for bytes, including trace/span IDs. This is diagnostic Protobuf JSON, not an
OTLP/HTTP JSON endpoint.

## 📝 Logs

The pinned `telemetry/logger/otlp.go` uses the otelslog bridge `v0.21.0` and log
exporter `v0.23.0`. The bridge's scope name is the service name; go-service does
not configure a scope version. Correlated and uncorrelated records share the
request, with nested typed attributes and a large integer.
The first log body includes quotes, a newline and text resembling logger fields
to verify that the complete content survives storage without interpretation.
`log_body_types.json` adds explicitly synthetic body-type/optional-context cases:
empty, string, boolean, signed integer extremes, finite/infinite doubles, bytes,
arrays, key-value lists, event names and dropped counts. Its `synthetic.scope` has
manufactured version/attribute/schema context, without claiming an emitted
go-service scope version. Empty resource/scope siblings verify that only context
for actual records is stored. `log_empty_contexts.json` supplies record-free
resource and scope headers; these exports must leave all log tables unchanged.
The representative log's unique request marker appears in both its attributes
and body, so payload-absence assertions also detect body-only diagnostics.

`log_write_conflict.json` contains four records across two resources and four
scopes. Its last timestamp repeats the first; `log_write_conflict.sql` installs
a test-only unique index on the reset disposable database to reject that later
insert. Each scenario first acknowledges and verifies retained logs with distinct
timestamps outside the conflict's values. Full log/resource/scope snapshots check
both rollback and preservation of those records; after the index is removed,
retry must store the complete export and retain the earlier records unchanged.
This index is never part of the application schema. Captured commit-failure
diagnostics must identify the failure without including the payload marker.

Runtime cases cover missing times, old/future times
and the full unsigned nanosecond range. `log_schema.sql` resets disposable
feature log tables and Goose history to verify initialization while preserving
unrelated fixture data. `migration_conflict.sql` creates a synthetic table-name
conflict: the initial migration fails after creating resource/scope tables and
their sequence, so the scenarios can verify transactional rollback, unchanged version-0 history
and successful startup/ingestion after repairing only that conflict.

`log_queries.json` supplies synthetic service/time boundaries, timestamp ties,
severities, correlation, typed values and literal search text for HTTP queries.
It also includes an unlabelled resource and a record with absent resource
context; all-service queries must return both with their original headers.
`log_query_arrivals.json` adds newer, equal-time and late arrivals after the first
page. `log_query_times.json` supplies original records for runtime unsigned/receipt
time cases. Each scenario substitutes a unique service identity. All-service
queries shift fixture event times into an isolated window, so labelled and
unlabelled records can be asserted without selecting records left by other scenarios.
Unsigned timestamp queries read one record per page to exercise high-bit cursor
encoding/decoding as well as record precision and token exhaustion.
Large-filter queries reuse these headers with two separately exported 500 KiB
string bodies and single-record gRPC pages under the existing receive limit.
`query_work.sql` temporarily replaces the disposable logs table with a view
that generates native scan work. Query cancellation tests use the named
`query_timeout.yaml` and `query_work.yaml` profiles through the existing
Nonnative process. Caller cancellation uses `query_cancellation.yaml`, whose
server and client budgets exceed the existing RSpec wait budget. It waits for native work,
cancels and verifies SQL release before reading continuation pages; client setup
and pagination latency are outside that release wait. Both native-work profiles
delay periodic health checks so SQL connection metrics measure query work alone.
The tagged scenario cleanup conditionally restores the real table, including
when setup or its restart fails.
The view is never part of the application schema and does not measure capacity.

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
RSpec's `have_otlp_export` matcher compares printed metric/trace requests;
`have_stored_log_export` and `have_log_times` check stored content and times.
`have_log_storage_growth` checks record and context allocation, while
`exclude_log_payload` searches all captured export output for the unique marker.
`have_log_commit` checks the committed diagnostic and exact exported-record count;
captured failure output must not contain any committed diagnostic.
The native `duckdb` Ruby gem is pinned to `2.0.0.1`, uses the MIT license and
needs DuckDB 2.0.0 from Homebrew locally or the prepared CI image. The existing
Cucumber/Nonnative lifecycle and configuration are reused.

Implementation conventions were checked against Bezeichner's
`internal/api/v1/transport/grpc/grpc.go` and Migrieren's module composition.
Einblick uses `internal/logs`, `internal/metrics` and `internal/traces`, with
direct `Register` functions and the shared transport lifecycle. Metric/trace
constructors remain logger-only; the log receiver consumes the composed local
`Repository`, whose logging decorator emits diagnostics. The upstream protobuf
packages remain v1. See [development](../../docs/development.md#-storage) for
the storage layout and migration workflow.

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
