# 🛠️ Operations

[← Back to README](../README.md)

## 🩺 Health

The development HTTP listener exposes:

| Endpoint | Behavior |
| --- | --- |
| `/einblick/healthz` | Online connectivity check. |
| `/einblick/livez` | No-op liveness check. |
| `/einblick/readyz` | No-op readiness check. |

```sh
curl --fail http://localhost:11000/einblick/healthz
curl --fail http://localhost:11000/einblick/livez
curl --fail http://localhost:11000/einblick/readyz
```

The gRPC health service checks `einblick`. These initial checks do not establish
storage readiness. See the [health wiring](../internal/health/health.go) and
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
C/C++ runtime image for Docker build, test and release targets. This prepares
the build for the planned DuckDB integration; storage is not implemented yet.

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
