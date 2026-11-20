![Gopher](assets/gopher.png)
[![CircleCI](https://circleci.com/gh/alexfalkowski/einblick.svg?style=svg)](https://circleci.com/gh/alexfalkowski/einblick)
[![codecov](https://codecov.io/gh/alexfalkowski/einblick/graph/badge.svg)](https://codecov.io/gh/alexfalkowski/einblick)
[![Go Reference](https://pkg.go.dev/badge/github.com/alexfalkowski/einblick.svg)](https://pkg.go.dev/github.com/alexfalkowski/einblick)
[![Stability: Active](https://masterminds.github.io/stability/active.svg)](https://masterminds.github.io/stability/active.html)

# 🔭 Einblick

Einblick is an OpenTelemetry service for applications built on go-service.
It receives logs, metrics and traces over gRPC. Logs commit to local DuckDB
storage before acknowledgement; metrics and traces print through the service
logger and are discarded.

The service recovers its local log database before serving requests and provides
bounded recent-log queries over gRPC and HTTP RPC. Browser pages, trace/metric persistence
and Parquet archives in Cloudflare R2 are planned.
See the [product requirements](docs/requirements.md) and
[implementation plan](docs/review-and-plan.md) for the remaining work.

## 🚀 Quickstart

Use Go, Ruby with Bundler, Make, a C/C++ compiler and native DuckDB
headers/library. macOS development uses Homebrew DuckDB; the configured CI image
includes the native dependency. See [development](docs/development.md) for details.
Run these commands from the repository root:

```sh
git submodule sync
git submodule update --init
make dep
make build
(cd test && ../einblick server -config file:.config/server.yaml)
```

In another terminal, check readiness:

```sh
curl --fail http://localhost:11000/einblick/readyz
```

The development configuration listens on HTTP port `11000` and gRPC port `12000`.
Its local database is `test/reports/recent.duckdb`. This development location is
disposable; use a persistent mount to retain accepted logs.

## 📥 Telemetry ingestion

Send standard OTLP/gRPC log, metric and trace exports to the gRPC listener, including with gzip.
See [telemetry ingestion](docs/ingestion.md) for receipt behavior, responses and a local
client example. Successful log exports acknowledge local commit. Successful
metric and trace exports acknowledge receipt only.

## 🔎 Log queries

Read acknowledged logs with service, severity, string-body text and trace-ID
filters through the [recent-log query API](docs/queries.md). Results preserve
typed content and exact nanoseconds, with stable newest-first pagination.

## ⚙️ Configuration

See [configuration](docs/configuration.md) for the development settings,
telemetry exporters, request limits and timeouts.

## 🛠️ Operations

See [operations](docs/operations.md) for health endpoints, persistent storage,
deployment and log recovery.

## 🧪 Development

See [development](docs/development.md) for the Cucumber harness, test output and
validation. Go API documentation is available on
[pkg.go.dev](https://pkg.go.dev/github.com/alexfalkowski/einblick), and release
history is available in [GitHub releases](https://github.com/alexfalkowski/einblick/releases).
