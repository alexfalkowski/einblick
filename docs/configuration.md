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
process memory. `threads` must be positive. The optional `spill_limit` bounds
DuckDB's temporary files on the database volume. Specify a size with a unit,
such as `32MiB`, or omit it to use DuckDB's default. The values above are
development settings, not production sizing recommendations.

## 🗃️ Local Parquet export

Add `archive` to enable the background exporter. Example development settings:

```yaml
duckdb:
  path: /data/recent.duckdb
  memory_limit: 64MiB
  spill_limit: 32MiB
  threads: 1
archive:
  workspace: /staging
  interval: 1s
  batch_size: 65536B
```

Mount a separate, quota-limited filesystem at `workspace` before starting
Einblick. When the volume is unmounted, the workspace path must be absent,
deny traversal to the service user, or be on a read-only filesystem. Removing
write permission from a traversable mount point still allows Einblick to
stage files in an existing writable `v1` outside the staging quota.

In the container deployment, mount the staging claim at `/staging` and keep
the container root filesystem read-only. On a host, use a mount point that
the service user cannot traverse until the staging volume is mounted.

Einblick creates `v1` if needed and restricts access to the service user.
Startup fails if Einblick cannot create or prepare the export directory.
Reserve write access on the mounted workspace for this instance and its
operators.
Begin with 1 GiB for testing and measure staged files and spill before sizing
production.

Each interval processes one batch, prioritizing interrupted work. `batch_size`
requires a positive decimal size such as `65KB` (65,000 bytes) or `65536B`.
It targets the uncompressed projected row bytes. An accepted row above that
target gets its own batch. Size the workspace to fit the largest such file and
the completed files it needs to hold. See [staging and recovery](operations.md#-local-parquet-staging).

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

## 🔎 Recent-log queries

All query limits are required, without implicit defaults:

```yaml
queries:
  max_results: 100
  max_range: 168h
  timeout: 30s
  concurrency: 1
```

`max_results` bounds each page and supplies its size when omitted or zero.
It must be positive and leave room for the extra row used to detect another
page. `max_range` is the largest selected event-time interval. `timeout`
covers queue waits and database work; `concurrency` bounds active queries.
Durations and concurrency must be positive.

These are development tuning values, not measured production capacity. The
development HTTP timeout is shorter than the query budget and can end a request
earlier. Align the transport and query budgets for the intended installation.
DuckDB's configured memory and thread settings also apply to reads. See
[recent-log queries](queries.md) for filtering, pagination and failure behavior.
