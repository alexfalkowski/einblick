# 🧪 Development

[← Back to README](../README.md)

## 🏁 Setup

Follow the [quickstart](../README.md#-quickstart). Use the Go version in
[go.mod](../go.mod) and Ruby with Bundler. Building DuckDB support requires CGO
and a C/C++ compiler.

The Ruby test client also needs native DuckDB headers and a shared library
compatible with the gem pinned in [test/Gemfile.lock](../test/Gemfile.lock).
On macOS, install DuckDB through Homebrew:

```sh
brew install duckdb
```

The gem detects Homebrew without extra build flags. The configured
[CI image](../.circleci/config.yml) already supplies the native dependency.

## 🥒 Tests and checks

Run commands from the repository root. The Cucumber/Nonnative harness starts
the server with [test/.config/server.yaml](../test/.config/server.yaml).
Choose the feature group you are changing:

```sh
make features tags=@storage
make features tags=@archive
make features tags=@queries
make features tags=@site
make features tags=@printing
make features feature=features/migrate
make features feature=features/health
```

Run groups one at a time because they share ports and the test database.
The Logs page includes a content fingerprint in each embedded CSS and
JavaScript URL. Rebuilding with changed assets gives browsers a fresh URL.
Shared actions live in `test/lib`; [fixtures](../test/fixtures/README.md) provide
synthetic OTLP payloads. Storage scenarios stop the server before inspecting its
database. Some scenarios reset that database, so use only the disposable test
configuration. Logs and reports go to `test/reports/`.

Use `make lint` for Go, Ruby and protobuf checks and `make help` for other commands.
After documentation edits, run:

```sh
python3 tools/check_handoff.py
```

## 🦆 Storage

`internal/duckdb` opens, instruments and closes the shared database.
`internal/logs/storage` keeps the `Repository` interface and composing
`NewRepository` constructor in `storage.go`. The database implementation and
transactional `Add` operation live in `repository.go`; the diagnostic decorator
lives in `logging.go`. SQL files live in `queries/` and are embedded as strings
declared in `queries.go`.

`Repository.List` supplies the versioned query operation in `internal/api/v1/logs`.
Both API transports use that typed adapter. The Logs MVC controller calls the
unversioned `Repository.List` operation directly.
Query validation, queueing and SQL execution share one
deadline. One go-sync semaphore bounds concurrent queries and allows waiting requests
to cancel; intake does not acquire it. Continuation pages use strict
event-time/ID keysets within fixed absolute bounds. New arrivals behind the
cursor can enter later pages; refresh to see arrivals ahead of it.

Keep timestamps as unsigned nanoseconds. Writes bind decimal strings to
`UBIGINT` to preserve the full unsigned range; conversions through floating-point
values or lower-precision timestamp types can lose data.

`internal/logs/archive` defines batches and coordinates recovery and export
through its batch repository and staged file interfaces. The Logs module
wires `internal/logs/storage` for durable state and native DuckDB
Parquet writes. `internal/logs/archive/staging` uses that writer to produce
verified Parquet and manages temporary paths, file checksums, and the final
rename. Startup prepares the workspace and clears partial output. The worker
checks recorded files before it begins staging batches on its ticks.

The v1 Parquet projection includes `log_id`, the four unsigned nanosecond
columns, and the stored protobuf JSON for `resource`, `scope` and `record`.
Readers can use DuckDB's `read_parquet` with `hive_partitioning = false` to read
the columns stored in completed files. The batch's logical digest covers these
columns in log-ID order. The staged file checksum covers the current Parquet
bytes.

## 🔌 Query API

The [protobuf contract](../api/einblick/v1/service.proto) defines the generated
gRPC and HTTP RPC request/response messages. `internal/api/v1` composes the
query operation and its `NewServer`/`Register` transport adapters. HTTP uses
`POST /einblick.v1.Service/ListLogs`; select `application/pbjson` for canonical
protobuf JSON with RFC 3339 Timestamp values. See [query usage](queries.md).

After changing the contract, regenerate Go and Ruby clients with:

```sh
make proto-format
make proto-generate
make proto-lint
```

Buf downloads the dependencies pinned in [api/buf.lock](../api/buf.lock) and
uses the remote plugins in [api/buf.gen.yaml](../api/buf.gen.yaml). Update the
OTLP schema dependency together with the Go and Ruby OTLP messages. Generated
files are checked in; edit the proto source and regenerate them.

## 🖥️ Logs site

The shared MVC server renders the embedded templates in
[`internal/site`](../internal/site). `GET /logs` returns a full document, and
the form and pagination use `PUT /logs` to replace the results fragment.
The [Logs route package](../internal/site/logs/route) wires both requests to
the controller. Change the [Logs views](../internal/site/logs/view) for
page-specific markup and `root/layout` for the shared page and fragment layouts.
Keep user-facing strings in each [locale catalog](../internal/site/locales).
The [full-page layout](../internal/site/root/layout/full.tmpl) pins htmx and the
daisyUI component stylesheets from jsDelivr with Subresource Integrity,
following Web. Use the shared daisyUI controls with the Einblick theme in the
[Logs stylesheet](../internal/site/static/logs.css). The theme, page layout and
request-status script ship in the binary.

## 🪿 Schema migrations

Application migrations live in `internal/migrate/migrations/`. Goose discovers
the numbered SQL files through `embed.FS` and applies pending migrations before
the listeners start. Its DuckDB history queries live in
`internal/migrate/queries/`, with embedded strings declared in `queries.go`.

For a schema change, add a numbered SQL file with a `-- +goose Up` section and
extend `test/features/migrate`. After release, leave applied migrations unchanged.
Each migration and its history entry commit together. Define the supported
rollback behavior for the change; see [recovery guidance](operations.md#-log-storage-and-recovery).

## 📦 Container builds

With Docker available, build for the required platform:

```sh
make build-docker platform=arm64
```

Use `platform=amd64` for that target. Keep `static=0` in the [Makefile](../Makefile):
DuckDB needs CGO and a compatible C/C++ runtime in the container.

## 📚 Product and design

The [requirements](requirements.md) define product behavior, and the
[implementation plan](review-and-plan.md) contains the remaining work.
The [initial design reference](requirements.md#87-service-catalog-and-standard-ux)
guides changes to the browser workflows.
