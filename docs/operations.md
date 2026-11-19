# 🛠️ Operations

[← Back to README](../README.md)

## 🩺 Health

The development HTTP listener exposes:

| Endpoint | Behavior |
| --- | --- |
| `/einblick/healthz` | Online connectivity check. |
| `/einblick/livez` | No-op liveness check. |
| `/einblick/readyz` | DuckDB connectivity check. |

```sh
curl --fail http://localhost:11000/einblick/healthz
curl --fail http://localhost:11000/einblick/livez
curl --fail http://localhost:11000/einblick/readyz
```

The gRPC health service checks `einblick` using the same DuckDB check. The local
database is opened and pinged during startup and closed during ordinary shutdown.
These checks establish connectivity, without proving durable telemetry intake,
schema recovery or sufficient free disk space. See the [health wiring](../internal/health/health.go) and
[health scenarios](../test/features/health/).

The development health configuration is:

```yaml
health:
  duration: 1s # Interval between checks.
  timeout: 1s # Timeout for the online check.
```

## 📦 Container builds

Container builds use the shared
[Go service Dockerfile](../bin/build/docker/go/Dockerfile). The service
[Makefile](../Makefile) sets `static=0`, enabling CGO and selecting the Debian 13
C/C++ runtime image for Docker build, test and release targets. DuckDB is now
linked into the service. The existing image targets are Linux amd64 and arm64;
deployed runtime validation remains with the owner.

The pinned driver is `github.com/duckdb/duckdb-go/v2 v2.20000.0`, with
`duckdb-go-bindings v0.20000.0` and DuckDB `2.0.0`. The driver, bindings and
bundled engine use the MIT license; dependency copies retain their license
files. The driver bundles static engine libraries for the supported platforms.
Its Arrow integration is opt-in and is not enabled by this service. Go's module
and vendor graphs include Arrow and other platforms' native libraries, which
does not establish that they are linked into the running binary.

The upstream [driver linking documentation](https://github.com/duckdb/duckdb-go/tree/v2.20000.0#linking-duckdb)
requires compatible native runtime libraries on Linux, including glibc; a bundled
static engine does not make the service fully static. The shared builder uses
Debian 13 and the runtime uses `cc-debian13`. No runtime extension installation
is added for local opening/pinging. Parquet export and remote-read extensions
remain later work; their behavior is not established by this integration.

Provide a writable persistent data directory, for example `/data`, owned by
the runtime UID, and configure `/data/recent.duckdb`. The WAL and engine spill
files belong alongside that file. See [database configuration](configuration.md#-local-database).
Non-root permissions, read-only-root operation, whole-process memory and native
runtime compatibility in the deployed images still need validation. No storage
provisioning or deployment configuration is changed here.

With Docker available, build a local ARM64 test image from the repository root:

```sh
make build-docker platform=arm64
```

## 🚢 Release and deployment

Releases publish notes on GitHub and Docker images for deployment. The `.cd`
marker enables automated deployment updates: the release image's `deploy`
command opens a version-bump PR in
[InfraOps](https://github.com/alexfalkowski/infraops).

Deployment configuration is managed in
[the InfraOps application definitions](https://github.com/alexfalkowski/infraops/blob/master/area/apps/apps.hjson)
and [Einblick configuration](https://github.com/alexfalkowski/infraops/blob/master/area/apps/lean/einblick.yaml).
See [CircleCI](../.circleci/config.yml) for the release and deployment workflow.

All-signal printing is implemented. This version discards telemetry and provides
no stored history or queries. Durable storage and recovery are planned features.
