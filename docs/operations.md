# 🛠️ Operations

[← Back to README](../README.md)

## 🩺 Health

| HTTP endpoint | Meaning |
| --- | --- |
| `/einblick/healthz` | External connectivity. |
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

Successful log exports mean the records committed locally. Restart recovery
uses the intact data path before accepting traffic. Metrics and traces are
currently printed and discarded. There is no retention or archive yet, so
monitor free space: accepted logs continue to consume the local volume.

Disk write failures return retryable `UNAVAILABLE`. Restore writable capacity
and allow clients to retry. Repeated exports can produce duplicate records.
Look for `component=logs` diagnostics to distinguish committed exports from
storage failures.

Pending schema migrations run automatically at startup. A failed migration
rolls back its own changes; earlier successful migrations remain applied.
Repair the reported cause and restart to retry. Do not manually advance recorded
versions to bypass an error.

An older binary refuses a database with a newer schema. There is no automatic
schema downgrade, so use a binary that supports the stored schema. Deleting the
database to bypass this check loses the retained logs.

## 🚢 Deployment

Use the [project container build](development.md#-container-builds) to package
DuckDB's native runtime requirements. The data directory must be writable by
the service's runtime user.

Deployment settings live in the [application definitions](https://github.com/alexfalkowski/infraops/blob/master/area/apps/apps.hjson)
and [Einblick configuration](https://github.com/alexfalkowski/infraops/blob/master/area/apps/lean/einblick.yaml).
See [CircleCI](../.circleci/config.yml) for the release workflow.
