# 📥 Telemetry ingestion

[← Back to README](../README.md)

## 📡 Export telemetry

The receivers implement these standard OTLP/gRPC methods using upstream
OpenTelemetry definitions, including gzip:

| Signal | RPC |
| --- | --- |
| Logs | `opentelemetry.proto.collector.logs.v1.LogsService/Export` |
| Metrics | `opentelemetry.proto.collector.metrics.v1.MetricsService/Export` |
| Traces | `opentelemetry.proto.collector.trace.v1.TraceService/Export` |

The [development configuration](configuration.md) exposes all three on gRPC
port `12000`.

Successful log exports commit all records and their resource/scope context in
one local DuckDB transaction before returning. Empty log requests are successful
no-ops. There is no background intake queue or dependency on R2. Successful
metric and trace exports still acknowledge receipt only and discard records.

Each metric or trace export prints one entry through the service logger. Its message
is the complete request as Protobuf JSON, including resource and scope context;
the `signal` field identifies `metrics` or `traces`. The payload is not
duplicated in a separate field. Empty requests print `{}`. Records are
discarded after printing. Logs emit a `component=logs` diagnostic with the
committed-record count, or a failure, without printing the incoming payload.
Acknowledged logs are available through the [recent-log query API](queries.md).

## 📝 Log support and delivery

The supported log contract is the decoded OTLP log schema in protobuf `v1.11.1`.
Storage preserves all its known log, resource and scope fields: typed bodies
and attributes, 64-bit integers, bytes, nested arrays/key-value lists, severity,
correlation IDs/flags, event names, dropped counts and schema URLs. Optional
resource/scope/body messages remain optional. Empty containers containing no
records do not create stored logs. Wire fields unknown to the pinned protobuf
are outside this support boundary.

The database stores typed Protobuf JSON, whose type tags and decimal-string
64-bit integers preserve the original values. Nanoseconds also have exact
`UBIGINT` columns. Timestamp selection follows
[the OTel log model](https://opentelemetry.io/docs/specs/otel/logs/data-model/):
use Timestamp, then ObservedTimestamp, then server receipt time if both are zero.
Both original timestamps remain unchanged; receipt time is stored separately.
Late and future timestamps are accepted without cutoffs, including the full
OTLP unsigned range. Archive-day selection is still planned.

Repeated exports create additional records, including identical logs. There is
no deduplication index or time horizon. A lost response or ambiguous commit may
therefore lead to duplicates when the client retries. Success promises recovery
on the intact local data path, without protecting against volume loss. See
[recovery and compatibility](operations.md#-log-storage-and-recovery).

Keep the receiver's own OTLP log exporter disabled to avoid recursive log export.
Keep its metric and trace exporters pointed away from its own listener too.
Use `info` or `debug` logging to see receipts.

## 📨 Responses

| Request | Response |
| --- | --- |
| Valid log export | Empty response after local commit, without partial success. |
| Valid empty log request | Empty response, without a database write or partial success. |
| Log database, disk, statement or commit failure | `UNAVAILABLE`; retryable, with no successful acknowledgement. |
| Log content that cannot be represented by the pinned protobuf JSON encoder | `INVALID_ARGUMENT`; permanent failure. |
| Cancelled or expired log write | `CANCELLED` or `DEADLINE_EXCEEDED`; the outcome may be ambiguous if commit raced cancellation. |
| Valid metric/trace export, including an empty request | Empty receipt-only response without partial success. |
| Message larger than the configured wire or decompressed limit | `RESOURCE_EXHAUSTED`; split or reduce the request. |
| Malformed protobuf | `INTERNAL` from the shared gRPC decoder. |

Log writes are atomic, so this implementation does not produce non-retried
partial-success responses. Storage backpressure uses retryable `UNAVAILABLE`,
following [OTLP retry guidance](https://opentelemetry.io/docs/specs/otlp/).
Size rejection remains the transport's non-retryable `RESOURCE_EXHAUSTED`.
No custom count, concurrency or free-space threshold is added. Existing records
are retained when new writes fail; disk backlog/retention policies remain later work.

## 🧪 Local client example

From the repository root, run:

```sh
make features tags=@printing
make features tags=@storage
```

The harness starts and stops the server. `@printing` covers metrics/traces;
`@storage` covers logs, including typed values, exact times, retries and restarts.
Inspect `test/reports/server.log` for metric/trace payloads and log diagnostics.
To select one signal, use its feature directory,
for example `make features feature=features/metrics/transport/grpc`.
See [development](development.md) for fixture details and the test harness.
