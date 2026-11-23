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

| Example location | Mount | Holds |
| --- | --- | --- |
| `/data` | Writable persistent volume | DuckDB database, adjacent WAL and spill files. |
| `/staging` | Separate quota-limited filesystem, mounted before startup | Temporary and completed Parquet files under `v1/`. |

Keep the container root filesystem read-only. On a host, use a mount point the
service user cannot traverse before mounting the staging volume. When unmounted,
the workspace path must be absent, inaccessible to the service user, or on a
read-only filesystem. A traversable mount point with an existing writable `v1`
lets files bypass the staging quota even if the mount point itself has no write
permission.

Einblick prepares `v1` for access by the service user and fails startup if
preparation fails. Reserve workspace write access for this instance and its
operators. Begin with 1 GiB for testing and measure staged files and spill
before sizing production.

The worker attempts one batch per interval after recovery, prioritizing
interrupted work. Set `batch_size` to a positive decimal size such as `65KB`
(65,000 bytes) or `65536B`. It targets uncompressed projected row bytes.
A larger accepted row gets its own batch. Allow room for the largest such file
and the completed files retained on the workspace. See [staging and recovery](operations.md#-local-parquet-staging).

## ☁️ R2 log archives

Add `r2` under the existing `archive` section to publish staged log batches:

```yaml
archive:
  workspace: /staging
  interval: 1s
  batch_size: 65536B
  r2:
    client:
      endpoint: https://ACCOUNT_ID.r2.cloudflarestorage.com
      timeout: 5s
    bucket: einblick
    region: auto
    access_key_id: file:/etc/secrets/einblick/r2-access-key-id
    secret_access_key: file:/etc/secrets/einblick/r2-secret-access-key
```

Provision the bucket and credentials with object read and write access before
enabling publication. Use the account's HTTPS S3 API endpoint and region `auto`
for R2. Einblick puts the bucket name in the URL path. For local Floci, use an
HTTP endpoint with a numeric loopback address such as `http://127.0.0.1:4566`.
Go bypasses environment HTTP proxies for loopback IPs. The credentials are
go-service sources read at startup and shared by publication and historical
reads. Restart to apply credential changes.

Use a dedicated bucket for the installation and restrict object writes to trusted
publishers. Historical queries discover Parquet objects directly from the bucket,
including on a fresh database volume. Give other consumers read-only access.

With R2 enabled, Einblick installs and loads DuckDB's signed `httpfs` extension
at startup. DuckDB downloads the matching binary from its extension repository
when it is absent from `$HOME/.duckdb/extensions`.
Give the service user a writable home and allow access to the extension
repository for an empty cache.
[Container setup](development.md#-container-builds)

With R2 enabled, positive `local_retention` sets how long to keep each accepted
row locally, measured from server receipt. All rows must be old enough and the
batch must be confirmed and cleaned before eviction. Omit the setting or use
`0s` to keep the local copies. Export cadence is independent of this window.
Before setting a positive value, verify that R2 enforces protection against
deletes and overwrites throughout the required archive retention period,
including when the worker evicts the local copy. Check the scope and remaining
duration of protection against the bucket's expiration policy. Keep eviction
disabled until that protection is in place.
[Cloudflare R2 bucket locks](https://developers.cloudflare.com/r2/buckets/bucket-locks/)

The worker attempts one publication per interval. The client streams uploads
and checksum verification, switching to multipart for large files.
`client.timeout` bounds each S3 request, including each upload part, the
full-object verification download, and multipart abort after cancellation.
Size it for the largest expected verification download at the available
throughput. Omit it to use the shared HTTP client default. DuckDB uses the
resolved timeout for historical object reads, rounded up to a whole second.
[Shutdown limitation](operations.md#-r2-publication-and-recovery)

The Go S3 clients support `client.tls`, `client.breaker`, and `client.retry`.
Log searches and the archive worker track circuit breaker failures separately.
With retries configured, only safe requests such as archive listings and
checksum reads can retry within the request timeout. The archive worker handles
write recovery. DuckDB uses its native TLS handling and makes its historical
object reads with retries disabled.

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
