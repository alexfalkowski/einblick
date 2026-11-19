# ⚙️ Configuration

[← Back to README](../README.md)

## ▶️ Start with the development configuration

After the [quickstart build](../README.md#-quickstart), start the server from the
repository root:

```sh
(cd test && ../einblick server -config file:.config/server.yaml)
```

The checked-in [configuration](../test/.config/server.yaml) owns the complete
development settings.

## 🦆 Local database

The `duckdb` section is required. The development configuration uses:

```yaml
duckdb:
  path: reports/recent.duckdb
  memory_limit: 64MiB
  threads: 1
```

The path is relative to the process working directory; the command above starts
in `test/`. Its parent directory must already exist and be writable. Use a
persistent mount and a filename such as `/data/recent.duckdb` for a container.
The path accepts a filename, without DSN parameters or `:memory:`. DuckDB owns
the adjacent WAL and spill directory. Keep that entire location writable and
retain it across restarts; do not move or delete an open database or its WAL.
Files under `test/reports` are disposable development output and can be removed
by report cleanup commands.

`memory_limit` and `threads` are explicit DuckDB engine settings with no service
defaults. The engine validates the memory value; the thread count must be
positive. `64MiB` and one worker are development settings, not measured
production sizing. DuckDB's memory setting does not bound the Go heap, every
native allocation or total process memory.

Startup opens the database and pings it through the service lifecycle. HTTP and
gRPC readiness use the shared database checker; ordinary shutdown closes the
database. Opening an invalid, inaccessible or already locked file fails startup.
There is no lock retry policy yet. Telemetry is still printed and discarded;
opening the file does not establish durable ingestion or restart recovery of
accepted telemetry. See [operations](operations.md) for packaging and remaining
storage limitations.

## 📊 Telemetry

The development configuration uses text logging at debug level, exposes
Prometheus metrics and exports the server's own traces to an OTLP collector at
`http://localhost:4318/v1/traces`.

DuckDB uses the shared go-service SQL instrumentation for operation traces,
operation duration metrics and connection-pool statistics, labelled with
`db.system.name=duckdb`. Raw SQL query text is excluded. With Prometheus enabled,
the metrics endpoint includes `einblick_db_sql_connection_open` and
`einblick_db_client_operation_duration_seconds_count` with `db_system_name="duckdb"`.
Shutdown unregisters the pool statistics and closes the database.

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
