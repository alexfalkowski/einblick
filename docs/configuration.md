# ⚙️ Configuration

[← Back to README](../README.md)

Use [test/.config/server.yaml](../test/.config/server.yaml) as a complete example.
The [quickstart](../README.md#-quickstart) shows how to run it.

## 🦆 Local database

All three `duckdb` settings are required:

```yaml
duckdb:
  path: reports/recent.duckdb
  memory_limit: 64MiB
  threads: 1
```

`path` is a database filename relative to the process working directory. Its
parent directory must already exist and be writable. In-memory databases and
DSN parameters are unsupported. Use a persistent mount for retained logs;
`test/reports/` is disposable. See [storage and recovery](operations.md#-log-storage-and-recovery)
for handling the database files across restarts.

`memory_limit` includes a unit and limits DuckDB's managed memory, not total
process memory. `threads` must be positive. The values above are development
settings, not production sizing recommendations.

## 🩺 Health checks

The `health` section requires a check interval and timeout:

```yaml
health:
  duration: 1s
  timeout: 1s
```

See [health endpoints](operations.md#-health) for what the checks establish.

## 📤 Self-telemetry

Keep Einblick's own OTLP log exporter disabled to avoid recursive log exports.
Point its metric and trace exporters at a different collector, never its own
OTLP listener.

See [telemetry ingestion](ingestion.md) for delivery semantics and request failures.
