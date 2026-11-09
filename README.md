[![CircleCI](https://circleci.com/gh/alexfalkowski/einblick.svg?style=svg)](https://circleci.com/gh/alexfalkowski/einblick)
[![codecov](https://codecov.io/gh/alexfalkowski/einblick/graph/badge.svg)](https://codecov.io/gh/alexfalkowski/einblick)
[![Go Reference](https://pkg.go.dev/badge/github.com/alexfalkowski/einblick.svg)](https://pkg.go.dev/github.com/alexfalkowski/einblick)
[![Stability: Active](https://masterminds.github.io/stability/active.svg)](https://masterminds.github.io/stability/active.html)

# einblick

Einblick collects logs, metrics, and traces for go-service services with DuckDB queries and Parquet archives in Cloudflare R2.

## Requirements

The [v1 specification](docs/requirements.md) defines the product behavior and
acceptance scenarios. The service scaffold and CGO opt-in exist; telemetry
implementation and installation remain outstanding.

Start with [the implementation plan](docs/review-and-plan.md) to select a packet
and find validation/handoff instructions. For UI work, use the
[initial design reference](docs/requirements.md#87-service-catalog-and-standard-ux).

## Development

Use the Go and Ruby toolchain provided by the
[CI image](.circleci/config.yml). The development workflow uses betteralign,
golangci-lint, and RuboCop. See
`make help` for supported commands and their prerequisites.

Local builds require CGO and a C/C++ compiler for the planned DuckDB
integration.

Initialize the shared tooling before using Make, then install dependencies and
build the server:

```sh
git submodule sync && git submodule update --init
make dep
make build
```

## Server

Start the server with the local development configuration:

```sh
./einblick server -config file:test/.config/server.yaml
```

The local configuration listens for HTTP on port `11000` and gRPC on port
`12000`. It exports traces to an OTLP collector at `http://localhost:4318`.
See [the configuration](test/.config/server.yaml) for transport timeouts, rate
limits, logging, and telemetry settings.

The planned telemetry receiver uses the standard OpenTelemetry OTLP/gRPC
services for logs, metrics, and traces. Its implementation will consume upstream
definitions; this repository has no custom protobuf API or generation step.

## Health

The server exposes service health, liveness, and readiness over HTTP:

```sh
curl --fail http://localhost:11000/einblick/healthz
curl --fail http://localhost:11000/einblick/livez
curl --fail http://localhost:11000/einblick/readyz
```

The initial checks use a no-op check for liveness and readiness, and an online
check for service health. The gRPC health service checks `einblick`.
See [the health wiring](internal/health/health.go) and
[health scenarios](test/features/health/) when adding dependency checks.

```yaml
health:
  duration: 1s # Interval between checks.
  timeout: 1s # Timeout for the online check.
```

## Deployment

Releases publish notes on GitHub and Docker images for deployment.

Container builds use the shared
[Go service Dockerfile](bin/build/docker/go/Dockerfile). The service Makefile
sets `static=0`, enabling CGO and selecting the Debian 13 C/C++ runtime image
for Docker build, test, and release targets (DEP-001). Build a local image with:

```sh
make build-docker platform=arm64
```

The `.cd` marker enables
automated deployment updates: the release image's `deploy` command opens a
version-bump PR in [InfraOps](https://github.com/alexfalkowski/infraops).
Deployment configuration is managed in
[the InfraOps application definitions](https://github.com/alexfalkowski/infraops/blob/master/area/apps/apps.hjson)
and [Einblick configuration](https://github.com/alexfalkowski/infraops/blob/master/area/apps/lean/einblick.yaml).
See [the CircleCI configuration](.circleci/config.yml) for the release and
deployment workflow.

## References

- [OTLP ingestion requirements](docs/requirements.md#81-ingestion)
- [Go package documentation](https://pkg.go.dev/github.com/alexfalkowski/einblick)
- [Releases](https://github.com/alexfalkowski/einblick/releases)
- [Shared tooling](bin/README.md)
