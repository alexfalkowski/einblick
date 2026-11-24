# Accepted design for archives

These entries are part of the [accepted-design index](../accepted-design.md).

## DuckDB extension installation

When R2 is configured, Einblick runs DuckDB's `INSTALL httpfs` and `LOAD httpfs`
during startup. A missing signed extension is downloaded for the linked engine
version and platform. Deployment supplies a writable home on the data volume.
[Container setup](../../development.md#-container-builds)

## Archive timestamps

Store archive and migration timestamps in UTC. For a DuckDB `TIMESTAMP`
column, construct SQL-generated values from Unix microseconds to avoid the
session time zone during conversion.

## DuckDB remote-read cancellation

Use DuckDB's native `httpfs` for E-08 archived Parquet reads. The owner
accepts that an in-flight request can outlive the query deadline or client
cancellation while DuckDB waits for the network operation. Pass the query
context to DuckDB and keep the connection, snapshot and admission slot until
the native read returns and query cleanup completes. The accepted exception
applies to the active native request.

On macOS arm64, DuckDB v2.0.0 with signed `httpfs` revision `77392a7207` returned
after 1.002 seconds on a stalled HEAD against a 100 ms context deadline, with
`http_retries=0` and `http_timeout=1` for the probe. This is an upstream
dependency defect. Use this entry when reviewing the E-08 read path and when
retesting after an upgrade or preparing upstream follow-up.
[DuckDB interruption issue](https://github.com/duckdb/duckdb/issues/28986)

## Staging mount at startup

Deployment supplies the quota-limited staging mount before startup. Without
the mount, the workspace must be absent, inaccessible to the service user, or
on a read-only filesystem. Einblick requires an existing writable workspace
and creates its private `v1` directory there. A writable backing directory can
receive files when the mount is absent. This is the deployment boundary
accepted for initializing an empty staging volume.
[Staging configuration](../../configuration.md#-local-parquet-export) · [Startup review](https://github.com/alexfalkowski/einblick/pull/38#pullrequestreview-6007322924)

## R2 publication endpoints

The publication client uses go-service's `SecureURL` validation. The supported
configuration uses HTTPS for R2 and a numeric loopback address for a local
HTTP emulator. The shared validator also permits loopback hostnames, which can
be subject to environment proxy handling. The owner accepted the documented
endpoint convention for publication.
[R2 configuration](../../configuration.md#-r2-log-archives) · [Publication review](https://github.com/alexfalkowski/einblick/pull/44#pullrequestreview-6011100920)

## R2 archive trust and eviction

Historical discovery trusts the configured archive bucket. Restrict bucket
writes to trusted publishers. Verify storage-enforced protection for the
required archive retention period before enabling R2. R2 enables local
eviction for older UTC event days after publication, staged file cleanup, and
remote checksum verification. Bucket policy protects the object through the
local deletion and subsequent reads.
[R2 configuration](../../configuration.md#-r2-log-archives)

## R2 archive retention

Archive retention uses the age of each R2 object. Infraops manages the
bucket lifecycle rule and R2 deletes eligible objects asynchronously. The
event timestamp still determines the archive partition and query bounds.
When the stored object time is unknown, use the R2 listing and report
unavailable history if a missing object's expiration cannot be established.
Verify the effective remote rule and rule removal through the R2 API.
Exercise Einblick with objects that remain listed after eligibility, objects
that disappear after expiration, and missing objects within retention.
Cloudflare's lifecycle contract supplies the deletion timing.
[Retention requirements](../../requirements.md#85-retention-and-delivery-semantics)

## Daily log export

The owner selected a 24-hour grace period after each UTC event day closes.
Daily export uses a complete batch for an eligible day and supplements it
with later arrivals grouped after their UTC receipt day closes. Keep the
current and previous UTC event days local. The owner selected a clean rollout
with a fresh database and empty staging workspace and archive bucket. The
bootstrap schema keeps log storage and archival in two migrations. The
intermediate archive schemas from development are retired.
[Daily archive configuration](../../configuration.md#-daily-log-archives)

Keep the batch identity and source rows when staging fails. Move the attempt
behind work already waiting so that another day can be published while the
batch is blocked. Read the source and Parquet projections in bounded pages
to calculate the same logical digest for the entire daily file.

## Early log disk backpressure

Log intake returns retryable `UNAVAILABLE` when local writes fail. At the
measured pilot load, the owner prioritized historical search performance and
deferred early disk backpressure under OPS-004. Revisit it when observed disk
usage or backlog growth during outages warrants a disk headroom policy.
[Capacity behavior](../../requirements.md#10-resource-latency-and-operational-requirements)

## S3 multipart abort during shutdown

The owner accepts that the S3 client can continue a stalled multipart abort
after the worker is cancelled. The abort can consume the service's shutdown
budget and leave DuckDB without a graceful close.
[Operations guidance](../../operations.md#-r2-publication-and-recovery)
