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

Each successful export prints one entry through the service logger. Its message
is the complete request as Protobuf JSON, including resource and scope context;
the `signal` field identifies `logs`, `metrics` or `traces`. The payload is not
duplicated in a separate field. Empty requests print `{}`. Records are
discarded after printing. Success acknowledges receipt only, with no stored
history or queries.

Keep the receiver's own OTLP log exporter disabled to avoid recursive log export.
Keep its metric and trace exporters pointed away from its own listener too.
Use `info` or `debug` logging to see receipts.

## 📨 Responses

| Request | Response |
| --- | --- |
| Valid export, including an empty request | Empty response for that signal's `Export` RPC, without partial success. |
| Message larger than the configured wire or decompressed limit | `RESOURCE_EXHAUSTED`; split or reduce the request. |
| Malformed protobuf | `INTERNAL` from the shared gRPC decoder. |

These responses describe receipt only. Durable acknowledgement remains part of
the [planned persistence work](review-and-plan.md).

## 🧪 Local client example

From the repository root, run:

```sh
make features tags=@printing
```

The harness starts and stops the server and sends plain, gzip, empty and
malformed requests for all three signals. Inspect `test/reports/server.log`
for the printed requests. To select one signal, use its feature directory,
for example `make features feature=features/metrics/transport/grpc`.
See [development](development.md) for fixture details and the test harness.
