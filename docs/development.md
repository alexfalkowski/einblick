# 🧪 Development

[← Back to README](../README.md)

## 🏁 Setup

Use Go matching [go.mod](../go.mod) and Ruby with Bundler. The
[CI image](../.circleci/config.yml) provides the project's Go and Ruby toolchain.
Git with GitHub SSH access is needed for the shared `bin` submodule. Make and
a C/C++ compiler are needed for the build, with CGO enabled for DuckDB.
Native local development is checked on macOS arm64; Linux amd64/arm64 are the
existing container build targets. Other native development platforms are not
validated by this change.

Follow the [quickstart](../README.md#-quickstart) to initialize the submodule,
install dependencies and build the server. Use `make help` from the repository
root for supported commands and their prerequisites. The development workflow
uses betteralign, golangci-lint and RuboCop.

## 🥒 Feature tests

The Ruby/Cucumber/Nonnative harness starts and stops the server using the
checked-in [development configuration](../test/.config/server.yaml).
Run the printing scenarios for all three signals from the repository root:

```sh
make features tags=@printing
```

Run the health scenarios with `make features feature=features/health`. They
check HTTP and gRPC readiness with the configured local database open.
They also verify that empty and in-memory database paths fail configuration
validation, and that a path naming a directory stops startup with a database-open
error. These cases use separate CLI invocations and checked-in configurations.
The existing harness starts the service in `test/` and closes it after the run.
These scenarios do not prove typed-value storage or crash recovery; the public
intake still discards telemetry. Database round-trip acceptance remains open
until storage validation is available.

The HTTP metrics scenario checks DuckDB connection-pool statistics and operation
duration samples with the DuckDB database-system label. This verifies the SQL
instrumentation through the service's metrics endpoint; remote trace delivery
still depends on the configured collector.

Server output and test results go to `test/reports/`. The synthetic OTLP fixtures follow the pinned
go-service sources and include resource/scope identity, typed nested values,
large integers and nanosecond timestamps. Metric fixtures cover gauges, sums
and histograms with exemplars; trace fixtures include linked spans and events. See the [fixture notes](../test/fixtures/README.md)
for source versions and provenance. The Ruby client uses upstream generated
OTLP messages; no custom protobuf API or generation step is introduced.

## 🦆 SQL instrumentation references

DuckDB consumes go-service `v3.2.0`'s
[`database/sql/telemetry/telemetry.go`](https://github.com/alexfalkowski/go-service/blob/v3.2.0/database/sql/telemetry/telemetry.go).
The direct opener and metric cleanup follow Migrieren's
[`internal/migrate/database/database.go`](https://github.com/alexfalkowski/migrieren/blob/0bc7d02426a1abf770d0c24cea25d648960bd67c/internal/migrate/database/database.go).
The shared defaults also serve
[`database/sql/pg/pg.go`](https://github.com/alexfalkowski/go-service/blob/v3.2.0/database/sql/pg/pg.go).
The local go-service checkout at `04f25241e9fe5390d0d51e88faf70c99e592582e`
was compared with the consumed version; these SQL reference files are unchanged.
The existing `*sql.DB` constructor, health consumers and lifecycle own the
connection; no writer/reader configuration or additional registration is needed.

## 📚 Product and design

The [requirements](requirements.md) define planned product behavior and
acceptance scenarios. The [implementation plan](review-and-plan.md) records
current progress and remaining feature work. The
[initial design reference](requirements.md#87-service-catalog-and-standard-ux)
shows the planned browser workflows.
