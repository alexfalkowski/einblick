# Implementation queue

[Requirements](requirements.md) own the product contract and open decisions.
This file contains feature implementation steps, dependencies, acceptance
coverage and saved progress. Agent workflow and engineering guidance live in
[AGENTS.md](../AGENTS.md).

## Continue from here

Say `Continue docs/review-and-plan.md`. Each continuation handles one step.

**Current step:** E-05 — Multilingual MVC Logs page.

**Status:** ready, pending owner review of the backend.

**Next action:** Owner review of the recent-log backend and versioned API,
then continue E-05 only. Implement the multilingual MVC Logs page over the
existing unversioned query operation, following Web's MVC/i18n pattern and the
initial design reference. Browser implementation has not started.

### Resume context

- [Recent-log queries](queries.md) owns the backend contract, defined by
  `api/einblick/v1/service.proto`. HTTP RPC uses
  `POST /einblick.v1.Service/ListLogs` with `application/pbjson` for canonical
  protobuf JSON; generated gRPC clients call the same `ListLogs` method.
  `internal/api/v1/logs.Service.ListLogs` adapts protobuf messages for both API
  transports. Future MVC controllers can use the unversioned
  `storage.Repository.List` operation directly, without protobuf or a network call.
  `start_time`/`end_time` are start-inclusive/end-exclusive protobuf Timestamps,
  represented as RFC 3339 in protobuf JSON. Preserve nanoseconds and the full
  unsigned OTLP range, including dates after 2262. Results retain typed OTLP
  resource/scope/record content and shared request metadata.
- API references: Bezeichner `ffffecc62f2d1d1a13737b844c304481c5a897f2`,
  `api/bezeichner/v1/service.proto`, `internal/api/v1/module.go`,
  `internal/api/v1/ids/list.go`, and `internal/api/v1/transport/{http,grpc}`.
  Shared identifier operations remain in Bezeichner's `internal/api/ids`.
  Standort `be79fd79d2d2b07567c7d44d9f0e5e5bd5bfc533`,
  `internal/location`, `internal/api/location` and `internal/api/v2/location`,
  and Migrieren `c3d07171068c5c53980a90979067db0755494278`,
  `internal/migrate`, `internal/api/migrate` and `internal/api/v1/migrate`,
  confirm the shared-core/versioned-adapter split. Their versioned modules and
  transports use the same operation-module, `NewServer` and `Register` pattern.
- Query limits are required configuration: development uses 100 records, 24h,
  30s and one active query. The shared HTTP timeout may end a request earlier.
  The single query semaphore uses consumed go-sync `v1.40.0`
  (`3a0d2bff9ea6949351be97f8504b18076d7b8940`), whose vendored
  `semaphore.go` matches the release. Intake does not acquire it.
- The owner deferred the [expanded-response security finding](https://github.com/alexfalkowski/einblick/pull/30#pullrequestreview-5990577441)
  until the functional workflow is working. The repository releases query
  admission before `internal/api/v1/logs/list.go` expands per-record headers;
  the pinned HTTP unary handler then buffers and writes the response outside
  that admission. Response-byte budgeting and admission through response
  completion remain unresolved. No new cap or lifecycle policy is selected.
- Pagination uses strict event-time/ID keysets. Arrivals behind the cursor may
  enter later pages; arrivals ahead require a fresh query. Existing records do
  not repeat. QRY-002/AC-004 own this agreed policy. Tokens survive restart and
  have no time expiry while local rows remain retained; E-09 must define source
  ownership/expiry before eviction. Do not introduce frozen membership or intake
  coordination when adding the view.
- WEB-017/AC-027 require embedded English, German and Spanish catalogs, browser
  preference negotiation, English fallback, localized labels/states/accessibility
  text and matching language/cache metadata in full/partial views. Telemetry and
  service identities retain their original values. No browser pages are implemented
  yet; E-05 owns the first rendering and language acceptance evidence.
- MVC/i18n reference: Web `d3b6694df26927ecbea2965c5015a33698306ea3`,
  `internal/site/site.go`, `internal/site/module.go`,
  `internal/site/books/controller/controller.go` and
  `test/features/site/site.feature`. Preserve the
  [initial design reference](requirements.md#87-service-catalog-and-standard-ux).
  Local go-service is consumed `v3.4.0`
  (`9986668a068488381a0600cd6dae3d189ed7f805`), matching the local checkout
  and vendored HTTP RPC/MVC implementations. Recheck its MVC/i18n implementation
  and Web's actual consumed framework/assets at E-05 entry. Shared bin is
  `00a890b21a01cfa4907262dfe19f9f2812b9e560`.
- Current API validation: `BUNDLE_USER_HOME=/tmp/einblick-bundler make features tags=@queries`
  passed 64 scenarios / 216 steps. The existing Cucumber/Nonnative harness uses
  generated Ruby messages for HTTP RPC assertions and a generated gRPC client.
  Coverage includes typed records/metadata, independently bounded receipt times,
  literal `%`/`_` search, omitted/empty service selection with labelled/unlabelled
  and absent-resource records, per-record headers, high-bit unsigned cursor
  continuation, independent trace-ID length/hex validation, safe gRPC storage failures,
  and complete single-record gRPC pages matching a 500 KiB text filter under the
  configured 1 MB receive limit. Tokens bind the normalized query through a
  fixed-size fingerprint, keeping filter text out of the token. Coverage also includes
  HTTP-to-gRPC continuation, narrow invalid unsigned bounds, invalid arguments, precision,
  arrival policy, restart, native deadlines and caller cancellation. Both page
  collectors reject repeated IDs/tokens and stop within an exported-fixture
  record bound. Caller cancellation waits for active SQL work, then verifies
  idle SQL within the existing 3s RSpec wait budget against separate 30s server
  query, gRPC transport and caller budgets. Continuation runs afterward in the same process. Native fixtures
  use tagged scenario cleanup, armed before setup and conditional on the source
  table's presence, so failed setup restarts also restore writable storage.
- `BUNDLE_USER_HOME=/tmp/einblick-bundler BUF_CACHE_DIR=/tmp/einblick-buf make lint`
  passed: Go 0 issues, Ruby 24 files without offenses, and protobuf format/lint.
  `BUF_CACHE_DIR=/tmp/einblick-buf make proto-update-all-dep proto-format proto-generate`
  passed. Repeating `make proto-generate` with that cache prefix left all four
  generated Go/Ruby files byte-identical. The host's default Buf cache is not
  writable in the agent sandbox; its documented override keeps normal Make
  targets usable. The dependency lock pins the same OTLP schema release as Go.
  `proto-breaking` was not run: no protobuf API exists in local `master` for
  comparison. `proto-stale` was not run because it compares the whole dirty
  worktree; generation was checked directly through the supported Make target.
- Refactor assessment covered local code/test smells, boundary ownership and
  public-contract compatibility. Versioned adapters own protobuf conversion,
  the unversioned repository owns query policy/work, and errors map locally in
  each transport. No further extraction is needed. Confidence in the tested
  local backend/API behavior is 95%; browser behavior, workload capacity and
  Linux/deployed native runtime evidence remain unavailable. CI owns the full
  service suite. Focused mutations were rejected for SQL LIKE wildcard search,
  event/receipt timestamp aliasing, repeated pages through HTTP and gRPC, and
  caller cancellation detached from the server query. Each failed its intended
  assertion through the feature harness; production sources were restored.
  Narrow boundary cases also rejected removal of each unsigned-bound check;
  all-service cases rejected broken empty-service filtering. A one-shot invalid
  startup command failed during native fixture setup, after which the existing
  ingestion/query scenario passed with the restored table. Cancellation passed
  with delayed continuation pages and rejected detached cancellation at the SQL
  release assertion. Temporary mutations and the startup command were restored.
- `GOPATH=/tmp/einblick-go GOMODCACHE=/Users/alejandro/go/pkg/mod TRIVY_SKIP_FILES='**/.env,**/.env.*' make sec`
  passed with current dependencies: govulncheck found no vulnerabilities across
  128 modules and Go 1.27.4; Trivy reported no matching critical Go/Ruby findings.
  The GOPATH prefix keeps checksum-cache writes in the sandbox without disabling
  verification; the Bundler prefix avoids host-home cleanup failures. Skip
  patterns preserve denied credential paths.
- `python3 tools/check_handoff.py` passed with 91 requirements, 27 acceptance
  scenarios and no unmapped IDs or broken local targets. Actual Linux CI, deployed native/runtime,
  rollout and workload-capacity evidence remain unavailable and owner-run.

## 1. Remaining steps

| Unit | Phase / entry | Remaining deliverable | Evidence to close |
| --- | --- | --- | --- |
| E-05 | P2; ready after owner review of E-04 | Add the thin MVC Logs page over the existing query path with safe rendering and visible loading/empty/error states. Introduce embedded English/German/Spanish catalogs and Web's language negotiation/fallback for full and partial views (WEB-017). | Log rendering in AC-015, initial frontend portions of AC-013/AC-016/AC-022/AC-027 and a useful local log investigation. No dashboard, trace view or login subsystem. |
| E-06 | P3; E-05 reviewed and log archive-day/membership/recovery policies recorded | Add durable log batch/export jobs, completed local Parquet files, content identity and interrupted-export/workspace recovery. | Log archive-format AC-003, local-export AC-009, pending-job AC-008 and derivative cleanup in AC-019. Verify typed/nanosecond Parquet round-trip and packaging. No R2 access, source deletion or uploadable partial files. |
| E-07 | P4; E-06 reviewed | Evaluate and integrate the lean S3 client and packaged DuckDB remote-read extensions. Verify access to a private test bucket and actual R2 operations before adding upload jobs. | AC-026 dependency/binary/resource evidence and actual upload/download/list/HEAD/delete, cancellation, reconciliation, pagination and multipart checks; separate DuckDB remote reads on required-platform service images. Log batches are sufficient at this gate. |
| E-08 | P4; E-07 reviewed | Add job-driven bounded upload/retry, content verification, ambiguous-outcome reconciliation and durable publication state for completed log batches. | Log remote AC-008/AC-009 and durable-transfer AC-026 integration. Keep local source rows until E-09; successful intake still depends only on local commit. |
| E-09 | P5; E-08 reviewed and source/reader ownership designed | Add selected-day discovery, DuckDB historical log reads, local/archive source selection, safe eviction and fresh-volume discovery. | Log AC-007/AC-011, eviction/cleanup AC-019, archived log AC-003 and historical failure/cancellation in AC-013/AC-016. Traces and metrics are not prerequisites. |
| E-10 | P6; E-09 reviewed and O-003 retention meaning selected | Add log retention and verify late/skew/retry policies, R2 outage/backpressure/backlog recovery and repeated concurrent resource/disk cycles. | Log AC-010/AC-012/AC-019 and measured bounds/health/recovery. |
| E-11 | P7; E-10 reviewed and trace fixtures/time/support/duplicate policies recorded | Replace trace printing with bounded local persistence, preserving events/links and commit-backed responses. | Trace ingestion portions of AC-001–AC-003 and local-record AC-008; typed/nanosecond round-trip, restart and bounds. Query portions remain open until E-12. |
| E-12 | P7; E-11 reviewed | Add fixed trace search/lookup, bounded waterfall/details and log correlation in the existing multilingual MVC application (WEB-017). | Local cross-service/midnight AC-005, trace query portions of AC-001/AC-013/AC-015, trace AC-027 and explicit incomplete/large-trace/context outcomes. |
| E-13 | P7; E-12 reviewed | Extend the existing Parquet/R2 pipeline, historical queries, eviction and retention to traces. | Archived trace AC-003/AC-005 and trace portions of AC-007–AC-012/AC-019, including interruption, outage, duplicate/conflict and mixed log/trace resource scenarios. |
| E-14 | P8; E-13 reviewed and metric fixtures/stream/time/support/duplicate policies recorded | Replace metric printing with bounded local persistence and commit-backed responses. | Metric ingestion portions of AC-001–AC-003 and local-record AC-008; typed/nanosecond round-trip, restart and bounds. Numerical queries remain a separate packet. |
| E-15 | P8; E-14 reviewed | Add fixed gauge/rate/histogram queries over representative go-service metric payloads before dashboard presentation. | Metric query portions of AC-001, AC-006 and numerical profile fixtures for AC-024, including resets, gaps, temporality and incompatible histograms. |
| E-16 | P8; E-15 reviewed | Extend the existing Parquet/R2 pipeline, historical queries, eviction and retention to metrics. | Metric archived AC-003, historical/lookback AC-006 and metric portions of AC-007–AC-012/AC-019. Exercise all signals together and close remaining all-signal backend response, recovery and resource cases. |
| E-17 | P9; E-16 reviewed | Add catalog validation and protocol-specific Overview panels over verified fixed metric queries, with embedded licensed assets and localized controls/chart/status text (WEB-017). | AC-023/AC-024: HTTP-only, gRPC-only, dual and worker entries; uncatalogued queries; units/aggregation labels; bounded charts; no-data/zero/stale states; Overview AC-027. |
| E-18 | P9; E-17 reviewed | Complete the existing multilingual MVC views, linked investigation, shareable absolute context, keyboard details, visible query/status outcomes and operator runbook. | Full AC-013/AC-015/AC-016/AC-022/AC-025/AC-027 and remaining frontend AC-023/AC-024. No site login/session subsystem. |

Each step has its own review boundary. E-07 owns remote feasibility.
Include composition/configuration with each
dependency's introduction. Feasibility checks do not replace later
service-boundary acceptance. R2 unavailability blocks P4, not P0–P3. Trace and
metric storage/query contracts and full recovery/archive evidence follow in P7/P8.

## 2. Shared infrastructure constraints

Reuse existing CGO, persistent-storage, R2 bucket/expiration and storage-aware
release tooling. Their interfaces are summarized in
[requirements section 6](requirements.md#6-existing-integration-surfaces).
No shared capability implementation or generic CGO trial is scheduled.

## 3. Design checks at implementation gates

These are the feature-specific decisions and scenarios for each packet.

| Gate | Required design or scenario |
| --- | --- |
| Signal fixtures at persistence/query introduction | Extend the existing fixtures for storage, unsupported shapes, typed values/nanoseconds, cross-service/midnight traces and cumulative/delta/reset/gap/histogram semantics. Record actual resource/scope/instance identity and instrumentation versions. Label manufactured edge cases as synthetic. |
| Ingestion limits | ING-004 uses existing go-service rate and request-size limits. Custom record-count, output-size and concurrency caps are not selected. |
| E-03/E-06/E-07 storage fidelity and packaging | Verify timestamp binding and typed/nanosecond round-trip in E-03, Parquet in E-06 and packaged remote extensions in E-07. Pin extension versions/licenses as introduced, without runtime internet installation. Deployed native-runtime and platform validation remains with the owner. A host CLI run does not establish image behavior. |
| E-03/E-11/E-14 response and retry | Commit failure never produces success. Distinguish non-retried partial-success from retryable temporary failure. Define each signal's duplicate/conflict behavior and bounded duplicate horizon when adding its persistence, then exercise retries after archival/eviction in E-10/E-13/E-16; avoid an indefinitely growing index. |
| E-03/E-11/E-14 recovery and compatibility | Reopen committed data and export state after interruption. Readiness waits for local recovery; R2 outage alone need not fail it. Close database users through the existing lifecycle and verify supported schema/runtime upgrades and rollback as each signal gains persistence. |
| Local schema changes at introduction | Extend the existing Goose history through numbered embedded migrations. Reject unsupported newer schemas; verify data-preserving upgrades, failed-migration recovery and the supported rollback behavior for each actual change under AC-017. |
| E-09 stable pagination | Preserve the fixed RFC 3339 query contract, strict event-time/ID keysets and agreed arrival policy across local/archive transitions. Define continued cursor ownership or explicit expiry before eviction. Keep string-body text-search scope labelled consistently. |
| E-15/E-16 metric correctness | Hand-check rates and histogram results for two instances, resets/start times, gaps, temporality, duplicate points and incompatible buckets in E-15. Aggregate compatible distributions before quantiles; verify lookback across midnight and local/archive boundaries in E-16. |
| E-06/E-08/E-09 archive ownership | Define durable batch transitions, immutable source membership, expected content identity, interrupted-transition recovery, per-query source ownership and reader cleanup lifetime as each capability is introduced. Cover upload success before local marking and derivative regeneration whose Parquet bytes may differ. Preserve a usable source through publication/eviction; query-time DISTINCT is insufficient. Extend and repeat for traces/metrics in E-13/E-16. |
| Resource bounds at introduction | Bound intake in E-03, query work in E-04, export/workspace in E-06 and upload/remote reads in E-07/E-08/E-09. Exercise ingestion/query/export/upload together in E-10 and repeat when adding traces/metrics. Measure database/WAL, spill and completed-file allocation through repeated eviction/checkpoint cycles; deleted rows do not prove reclaimed disk. Reserve space for metadata commits and backlog recovery. |
| E-17/E-18 browser acceptance | Verify URL round-trip/return navigation, keyboard row/span access, bounded large traces, missing correlation and stale/partial/error/cancelled outcomes. Filter Overview traces to active instance/time scope; preserve search focus/caret/selection on refresh. The synthetic prototype leaves these behaviors unproven. |

## 4. Acceptance coverage

The table assigns evidence ownership for these feature steps; it does not mark a scenario passed.
Partial local/signal evidence is not full archive/all-signal acceptance.

| Acceptance | Planned evidence owner |
| --- | --- |
| AC-001 | Log durable intake in E-03 and queries in E-04; trace intake/query in E-11/E-12; metric intake/query in E-14/E-15. Receipt-only responses do not pass this scenario. |
| AC-002 | E-03/E-11/E-14 for signal support/responses and local admission failures; E-10/E-13/E-16 for archive-outage capacity behavior. |
| AC-003 | Log local typed/precision evidence in E-03, Parquet in E-06 and archived queries in E-09; traces in E-11/E-13; metrics in E-14/E-16. |
| AC-004 | E-04 ordering/pagination, repeated across local/archive transitions in E-09. |
| AC-005 | E-12 local distributed trace; E-13 archived/midnight lookup. |
| AC-006 | E-15 numerical metric semantics; E-16 historical/lookback continuity. |
| AC-007 | E-09 actual log overlap/publication/eviction queries; repeat for traces/metrics in E-13/E-16. |
| AC-008 | E-03/E-11/E-14 committed-record recovery; E-06/E-08 pending log export/publication recovery, extended to traces/metrics in E-13/E-16. |
| AC-009 | E-06 interrupted local log export; E-08 ambiguous remote publication; repeat for traces/metrics in E-13/E-16. |
| AC-010 | E-10 log outage, visibility, backpressure and backlog recovery; repeat for traces/metrics in E-13/E-16. |
| AC-011 | E-09 fresh-volume log archive discovery and reads; repeat for traces/metrics in E-13/E-16. |
| AC-012 | E-10 log policy/retry/expiration scenarios, using E-03/E-06 policies; extend with trace/metric policies in E-13/E-16. |
| AC-013 | Query bounds/cancellation from E-04 onward, log historical work in E-09/E-10, trace/metric coverage in E-12/E-13/E-15/E-16, browser completion in E-18. |
| AC-014 | Reserved; no v1 work. |
| AC-015 | E-05/E-12 establish safe rendering/correlation; E-18 completes navigation acceptance. |
| AC-016 | E-03 independent diagnostics, E-05 initial frontend states; E-09/E-10 log backend coverage/failure/recovery, extended in E-13/E-16; E-18 completes visible frontend outcomes. |
| AC-017 | Local versioned-migration/initialization/failure-recovery baseline from E-03; archive/schema evidence from E-06/E-09 and trace/metric additions; supported schema/runtime upgrade and rollback checks with each persistence/archive change. |
| AC-018 | E-03/E-11/E-14 service recovery, shutdown and database reopen; E-06 Parquet and E-07 remote-extension packaging. Deployed runtime validation is owned by the operator. These are portions of the broader requirements scenario. |
| AC-019 | E-06 derivative cleanup, E-09 safe complete-batch log eviction, E-10 expiration/workspace cycles; repeat for traces/metrics in E-13/E-16. |
| AC-021 | E-04/E-09/E-12/E-13/E-15/E-16 DuckDB query review; E-06/E-08/E-13/E-16 immutable export review. Preserve the shared CGO build default with each change. |
| AC-022 | E-05 initial Logs view without site credentials/sessions; E-18 full browser-workflow evidence. |
| AC-023 | E-17 catalog behavior and uncatalogued queries, completed frontend evidence in E-18. |
| AC-024 | E-15 verified profile/numerical fixtures, E-16 historical continuity, E-17 charts and bounded states. |
| AC-025 | E-18 connected investigation, links, selections, keyboard details and explicit trace scope. |
| AC-026 | E-07 actual-R2/dependency/binary/resource evidence, E-08 durable transfer integration, resource checks repeated with trace and metric archive support. |
| AC-027 | E-05 multilingual Logs page/catalog foundation; E-12 trace views; E-17 Overview; E-18 complete navigation, accessibility and error/status language coverage. Follow WEB-017 and Web's existing full/partial language scenarios. |
