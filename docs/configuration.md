# ⚙️ Configuration

[← Back to README](../README.md)

## ▶️ Start with the development configuration

After the [quickstart build](../README.md#-quickstart), start the server from the
repository root:

```sh
./einblick server -config file:test/.config/server.yaml
```

The checked-in [configuration](../test/.config/server.yaml) owns the complete
development settings.

## 📊 Telemetry

The development configuration uses text logging at debug level, exposes
Prometheus metrics and exports the server's own traces to an OTLP collector at
`http://localhost:4318/v1/traces`.

The receivers use the configured service logger directly. Keep the server's own
OTLP log exporter disabled to avoid recursive export, and use `info` or `debug`
level to see receipts. Keep its metric and trace exporters pointed away from
its own OTLP listener too.

## 🚦 Listeners and limits

| Setting | Development value |
| --- | --- |
| HTTP listener | `tcp://:11000` |
| gRPC listener | `tcp://:12000` |
| gRPC maximum receive size | `1MB` (1,000,000 bytes), including after gzip decompression |
| HTTP and gRPC rate limiter | 1,000 requests per second per service and method |
| HTTP and gRPC timeout | `5s` |

The shared gRPC unary timeout starts after decoding; clients should set their
own deadlines. The receiver adds no record-count, output-size or concurrency
cap. See [telemetry ingestion](ingestion.md) for protocol responses and
[operations](operations.md) for health endpoints.
