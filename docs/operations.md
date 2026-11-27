# 🛠️ Operations

[← Back to README](../README.md)

## 🩺 Health

| HTTP endpoint | Meaning |
| --- | --- |
| `/einblick/healthz` | External and DuckDB connectivity. Returns HTTP 503 if either check fails. |
| `/einblick/livez` | Process liveness, independent of the database. |
| `/einblick/readyz` | Database connectivity after startup recovery and migrations. |

The gRPC health service `einblick` uses the same database check as readiness.
Readiness does not establish free disk space or writable capacity.
With the development configuration:

```sh
curl --fail http://localhost:11000/einblick/readyz
```

## 🦆 Log storage and recovery

Set [the database path](configuration.md#-local-database) on a writable persistent
mount, for example `/data/recent.duckdb`. Retain the database, adjacent WAL and
spill files together across restarts. Stop the service before moving them.
A locked database file fails startup; the previous process must close it before
a replacement can open it for writing.

On restart, Einblick recovers DuckDB and applies pending migrations before
accepting traffic. Keep the volume to recover acknowledged logs. Staging
Parquet files leaves the source rows in DuckDB, where they continue to use space.

Disk write failures return retryable `UNAVAILABLE`. Restore writable capacity
and allow clients to retry. Repeated exports can produce duplicate records.
Look for `component=logs` diagnostics to distinguish committed exports from
storage failures.

Recent-log reads use the same recovered database; see
[query scope, pagination and failures](queries.md). A query failure does not
mean that previously acknowledged logs were discarded.

Pending schema migrations run automatically at startup. A failed migration
rolls back its own changes; earlier successful migrations remain applied.
Repair the reported cause and restart to retry. Do not manually advance recorded
versions to bypass an error.

An older binary refuses a database with a newer schema. There is no automatic
schema downgrade, so use a binary that supports the stored schema. Deleting the
database to bypass this check loses the retained logs.

## 🗃️ Local Parquet staging

When [enabled](configuration.md#-local-parquet-export), the exporter stages
completed log batches under `v1/signal=logs/day=YYYY-MM-DD/<batch-id>.parquet`
on its own quota-limited workspace. It uses the UTC day of the selected event
time. A late record can create another batch for the same day.

```mermaid
flowchart TD
    accTitle: Archive worker startup and first recovery
    accDescr: Startup prepares the workspace. The worker verifies or requeues staged files before new exports and uploads. It can reconcile recorded publication and attempt eligible eviction on a tick while recovery is blocked.
    Start[Prepare workspace and clear partial output] --> Verify[Check completed files on worker tick]
    Verify -->|Missing or damaged| Requeue[Requeue with same batch ID]
    Requeue -->|Continue scan| Verify
    Verify -->|Recovery error| Reconcile[Try R2 publication reconciliation and cleanup]
    Reconcile --> Eviction[Try eligible R2-backed eviction]
    Eviction --> Retry[Retry recovery on next tick]
    Retry --> Verify
    Verify -->|Recovery complete| Work[Resume normal worker ticks]
    Work --> Stage[Try export, publication and eviction in order]
```

Publication and eviction apply when R2 is configured. DuckDB records the
batch's exact members before computing the logical digest.
The exporter verifies the written rows, renames the file, and records its
byte checksum.
Recovery uses the retained rows to regenerate files while ingestion and recent
queries stay available.

When a batch fails to stage, it retains its identity and source rows and moves
behind work already waiting. A daily file that exceeds the staging capacity
can remain pending while smaller batches proceed. Inspect `component=log_archive`
diagnostics and restore enough writable capacity for the blocked file. Keep the
database and staging mount accessible at startup when export is enabled. If
the prepared workspace is missing or changed, restore the original mount and
its `v1` directory so the worker can retry. After intentionally replacing the
workspace, mount the replacement and restart Einblick. Startup initializes the
export directory on the new filesystem so the worker can regenerate missing
files from retained logs.

## ☁️ R2 publication and recovery

With [R2 configured](configuration.md#-r2-log-archives), the archive worker
publishes each closed batch to the same versioned key as its staged path.
OTLP acknowledges the local DuckDB commit. Publication and staging cleanup run
in the background. Queries use the local copy until its batch is evicted.

Before sending a file, the worker records its SHA-256 in DuckDB. R2 writes are
conditional on the key being absent. After upload or on retry, the worker
checks the object's metadata and streams its bytes to verify a recorded
checksum. This also recognizes a successful upload after restart, even if
staging is missing, cannot be regenerated, or has been regenerated with
different Parquet bytes. The worker can reconcile recorded upload attempts and
retry cleanup while local recovery is blocked by unreadable staging. New
exports and uploads resume after local recovery succeeds. Cleanup remains
pending after confirmation until the staged file has been removed or is absent.

For publication failures, inspect `component=log_archive` diagnostics, the
configured endpoint and bucket permissions, and the remaining staging
capacity. The archive exports these OpenTelemetry gauges.

| Metric | Unit | Meaning |
| --- | --- | --- |
| `log_archive.pending.records` | `{record}` | Accepted records awaiting publication. |
| `log_archive.pending.size` | `By` | Pending record JSON size, excluding shared OTLP headers and Parquet encoding overhead. |
| `log_archive.pending.oldest_age` | `s` | Age of the oldest pending record since receipt. |
| `log_archive.last_publication.timestamp` | `s` | Unix timestamp of the latest confirmed publication. |

An empty backlog reports zero pending records, bytes and age. An archive with
no confirmed publication reports a zero timestamp. Metrics collections use the
latest sample from the background sampler.
Each read uses `queries.timeout`. After it returns, the sampler rests for the
longer of `archive.interval` and the time spent reading. Until a sample
succeeds, or after a failed refresh, these gauges are omitted. Unconfirmed batches
retain their source rows. Publication and eviction attempts move each batch to
the end of its durable retry queue. The worker retries damaged staging in the
same publication rotation. A blocked repair leaves the export slot available
for new logs on other days. If the key contains conflicting bytes, investigate the
bucket and key ownership before changing the object. The worker preserves an
existing object and leaves the batch pending when verification fails. If
verification repeatedly times out, check that `archive.r2.client.timeout`
covers the full download. If publication succeeds but workspace cleanup fails,
restore staging access so the worker can reclaim the file.

The S3 client can continue a multipart abort after worker cancellation. A
stalled abort shares `archive.r2.client.timeout` with transfers, subject to the
client's one-minute abort cap. If it uses the remaining time in the application's
15-second shutdown budget, the process may exit before DuckDB closes cleanly.
Incomplete multipart uploads follow the bucket's incomplete-upload lifecycle
policy.

## 🔎 Historical log availability

When R2 is configured, the query API and Logs page discover Parquet objects in
the selected UTC days. A fresh database volume can query existing objects as
soon as it can reach the configured bucket. Keep the same bucket when reopening
a database that has evicted batches. If R2 is unconfigured on that volume,
searches overlapping UTC days with evicted batches report unavailable storage.

Historical reads include existing `v1` Parquet objects. Einblick records object
upload time at eviction and can also use the timestamp from the R2 listing.
If a search requires a missing object and its upload time is unknown, the search
reports unavailable history. For the database volume, follow the
[schema rollback guidance](#-log-storage-and-recovery).

With [R2 configured](configuration.md#-r2-log-archives), the worker downloads a
confirmed object and verifies its checksum before deleting the batch's local
source rows. The current and previous UTC event days remain local. Count this
GET in the
[R2 Class B operation budget](https://developers.cloudflare.com/r2/pricing/#class-b-operations).
Look for `local log archive eviction failed` under `component=log_archive` when
eligible batches stay local. A missing, unavailable or changed object leaves its
source rows in DuckDB. The worker continues with other eligible batches and
retries the blocked batch. A failed historical query reports unavailable storage.
Restore access to the bucket and retry the same absolute interval.

When `archive.r2.retention` is set, a successful archive listing can
omit an expected object that has reached the configured age. Einblick reads
eligible objects that R2 still lists until the bucket removes them. Missing
objects within the retention guarantee and failed listings report unavailable
storage. Queries use the listing timestamp when available. For an unlisted
object, Einblick allows for the one-second precision of the recorded R2
`Last-Modified` before treating it as expired. If an eligible listed object
disappears during a read, Einblick refreshes the listing and retries the search
once after confirming the object is gone. During an outage, choose a recent
time preset or select **Open Logs** to return to the default recent range.
Retry the original range after archive access returns.

## ♻️ Changing archive retention

Update the bucket lifecycle in Infraops and verify the effective remote rule
before matching `archive.r2.retention` and restarting Einblick. R2 applies
changes asynchronously. Increasing retention or disabling expiration cannot
restore deleted objects, and the new guarantee can make previously expired
objects show as unavailable. Use the Infraops procedure to explicitly remove
or disable the remote lifecycle rule and verify the result. Removing the
setting from either configuration leaves no evidence that the remote rule
stopped running.
[Infraops R2 object expiration](https://github.com/alexfalkowski/infraops#-r2-object-expiration)

## 🚢 Deployment

Use the [project container build](development.md#-container-builds) to package
DuckDB's native runtime requirements. The data directory must be writable by
the service's runtime user.

Deployment settings live in the [application definitions](https://github.com/alexfalkowski/infraops/blob/master/area/apps/apps.hjson)
and [Einblick configuration](https://github.com/alexfalkowski/infraops/blob/master/area/apps/lean/einblick.yaml).
See [CircleCI](../.circleci/config.yml) for the release workflow.
