# 🧪 Development

[← Back to README](../README.md)

## 🏁 Setup

Use Go matching [go.mod](../go.mod) and Ruby with Bundler. The
[CI image](../.circleci/config.yml) provides the project's Go and Ruby toolchain.
Git with GitHub SSH access is needed for the shared `bin` submodule. Make and
a C/C++ compiler are needed for the build, with CGO enabled for the planned
DuckDB integration.

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

Server output and test results go to `test/reports/`. The synthetic OTLP fixtures follow the pinned
go-service sources and include resource/scope identity, typed nested values,
large integers and nanosecond timestamps. Metric fixtures cover gauges, sums
and histograms with exemplars; trace fixtures include linked spans and events. See the [fixture notes](../test/fixtures/README.md)
for source versions and provenance. The Ruby client uses upstream generated
OTLP messages; no custom protobuf API or generation step is introduced.

## 📚 Product and design

The [requirements](requirements.md) define planned product behavior and
acceptance scenarios. The [implementation plan](review-and-plan.md) records
current progress and remaining feature work. The
[initial design reference](requirements.md#87-service-catalog-and-standard-ux)
shows the planned browser workflows.
