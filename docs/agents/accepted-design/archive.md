# Accepted design for archives

These entries are part of the [accepted-design index](../accepted-design.md).

## DuckDB extension installation

When R2 is configured, Einblick runs DuckDB's `INSTALL httpfs` and `LOAD httpfs`
during startup. A missing signed extension is downloaded for the linked engine
version and platform. Deployment supplies a writable home on the data volume.
[Container setup](../../development.md#-container-builds)

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
writes to trusted publishers. Keep local eviction disabled until storage-enforced
protection covers the required archive retention period.
Checksum verification covers the bytes read before eviction. Bucket policy
protects the object through the local deletion and subsequent reads.
[R2 configuration](../../configuration.md#-r2-log-archives)

## S3 multipart abort during shutdown

The owner accepts that the S3 client can continue a stalled multipart abort
after the worker is cancelled. The abort can consume the service's shutdown
budget and leave DuckDB without a graceful close.
[Operations guidance](../../operations.md#-r2-publication-and-recovery)
