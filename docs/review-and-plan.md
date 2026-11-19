# Implementation queue

[Requirements](requirements.md) own the product contract and open decisions.
This file contains feature implementation steps, dependencies, acceptance
coverage and saved progress. Agent workflow and engineering guidance live in
[AGENTS.md](../AGENTS.md).

## Continue from here

Say `Continue docs/review-and-plan.md`. Each continuation handles one step.

**Current step:** E-04 — Query recent logs.

**Status:** ready; owner review of E-03 remains the entry condition.

**Next action:** After owner review, define the fixed recent-log query contract:
absolute time bounds, text-search scope, stable ordering/pagination, supported
range/result/work bounds and cancellation. Implement only that backend increment;
keep the MVC page for E-05.

### Resume context

- Requirements O-004/O-005/O-006 own the agreed log time, duplicate and support
  policies. Schema version 1 stores shared resource/scope headers and individual
  typed log records. [Operations](operations.md#-log-storage-and-recovery) covers
  recovery and compatibility; [development](development.md#-storage) explains
  the storage layout and migration workflow.
- E-04 must preserve unsigned nanosecond precision. Log timestamps bind as
  decimal strings to `UBIGINT`; the instrumented prepared-statement path rejected
  high-bit `uint64` values. The supported full-range value
  `18446744073709551615` passes storage round-trip. Receipt time and sequence
  allocation precede commit, and IDs may have gaps; a pagination receipt boundary
  must account for in-flight commits rather than assuming commit order.
- The application schema is owned by `internal/migrate`; future local DDL goes
  in its next numbered embedded migration (`00002_*.sql`), not in log insert
  queries or a second migration history. Goose is the sole schema history;
  pre-release bootstrap compatibility is not required. Startup applies only Up;
  [operations](operations.md#-log-storage-and-recovery) owns rollback
  and failure-repair behavior. New schema/runtime changes still need their own
  upgrade/rollback evidence for AC-017.
- Native tests use the owner's existing Homebrew DuckDB 2.0.0 and ordinary
  Bundler detection without native build overrides. CI consumes
  `alexfalkowski/go:5.25` with the native header/library prepared in root `3.28`.
  No runtime downloader, dependency override or extra native installation is
  required by Goose.
- Local acceptance evidence needed by the query increment:
  `BUNDLE_USER_HOME=/tmp/einblick-bundler make features tags=@storage` passed
  24 scenarios / 118 steps, covering stored content/timestamps, record-free and
  mixed-context allocation, full-row preservation after commit failure,
  later-record rollback/retry, payload-free diagnostics, ordinary/interrupted
  reopen, fresh schema initialization with unrelated data,
  unchanged records/IDs/history on restart, newer Goose rejection and DDL rollback
  followed by repair/retry. `BUNDLE_USER_HOME=/tmp/einblick-bundler make lint`
  passed with Go 0 issues and Ruby 17 files without offenses.
- `GOPATH=/tmp/einblick-go GOMODCACHE=/Users/alejandro/go/pkg/mod TRIVY_SKIP_FILES='**/.env,**/.env.*' make sec`
  passed: govulncheck scanned 128 modules plus Go 1.27.4 without reported
  vulnerabilities, and Trivy reported no matching critical Go/Ruby dependency
  findings. The GOPATH override places the checksum cache in a sandbox-writable
  location without disabling verification; use that prefix for dependency
  commands here. The temporary Bundler home avoids host-home/fork cleanup
  failures. Skip patterns preserve denied credential paths.
- Confidence in the tested local behavior is 95%. Actual Linux CI and deployed
  native/platform/rolling-update execution were not observed. Those broader
  AC-018 observations remain owner-run and unavailable. The denied WAL write is
  not full-volume exhaustion or backlog recovery; resource cycles remain E-10.
  Queries and full AC-001 remain open for E-04.

## 1. Remaining steps

| Unit | Phase / entry | Remaining deliverable | Evidence to close |
| --- | --- | --- | --- |
| E-04 | P2; E-03 reviewed | Add fixed recent-log queries with stable ordering/pagination, documented search/time scope, bounded work and cancellation. | Log AC-001/AC-004 and backend bounds/cancellation in AC-013. Read back acknowledged records, including after restart. No browser or R2 dependency. |
| E-05 | P2; E-04 reviewed | Add the thin MVC Logs page over the existing query path with safe rendering and visible loading/empty/error states. | Log rendering in AC-015, initial frontend portions of AC-013/AC-016/AC-022 and a useful local log investigation. No dashboard, trace view or login subsystem. |
| E-06 | P3; E-05 reviewed and log archive-day/membership/recovery policies recorded | Add durable log batch/export jobs, completed local Parquet files, content identity and interrupted-export/workspace recovery. | Log archive-format AC-003, local-export AC-009, pending-job AC-008 and derivative cleanup in AC-019. Verify typed/nanosecond Parquet round-trip and packaging. No R2 access, source deletion or uploadable partial files. |
| E-07 | P4; E-06 reviewed | Evaluate and integrate the lean S3 client and packaged DuckDB remote-read extensions. Verify access to a private test bucket and actual R2 operations before adding upload jobs. | AC-026 dependency/binary/resource evidence and actual upload/download/list/HEAD/delete, cancellation, reconciliation, pagination and multipart checks; separate DuckDB remote reads on required-platform service images. Log batches are sufficient at this gate. |
| E-08 | P4; E-07 reviewed | Add job-driven bounded upload/retry, content verification, ambiguous-outcome reconciliation and durable publication state for completed log batches. | Log remote AC-008/AC-009 and durable-transfer AC-026 integration. Keep local source rows until E-09; successful intake still depends only on local commit. |
| E-09 | P5; E-08 reviewed and source/reader ownership designed | Add selected-day discovery, DuckDB historical log reads, local/archive source selection, safe eviction and fresh-volume discovery. | Log AC-007/AC-011, eviction/cleanup AC-019, archived log AC-003 and historical failure/cancellation in AC-013/AC-016. Traces and metrics are not prerequisites. |
| E-10 | P6; E-09 reviewed and O-003 retention meaning selected | Add log retention and verify late/skew/retry policies, R2 outage/backpressure/backlog recovery and repeated concurrent resource/disk cycles. | Log AC-010/AC-012/AC-019 and measured bounds/health/recovery. |
| E-11 | P7; E-10 reviewed and trace fixtures/time/support/duplicate policies recorded | Replace trace printing with bounded local persistence, preserving events/links and commit-backed responses. | Trace ingestion portions of AC-001–AC-003 and local-record AC-008; typed/nanosecond round-trip, restart and bounds. Query portions remain open until E-12. |
| E-12 | P7; E-11 reviewed | Add fixed trace search/lookup, bounded waterfall/details and log correlation in the existing MVC application. | Local cross-service/midnight AC-005, trace query portions of AC-001/AC-013/AC-015 and explicit incomplete/large-trace/context outcomes. |
| E-13 | P7; E-12 reviewed | Extend the existing Parquet/R2 pipeline, historical queries, eviction and retention to traces. | Archived trace AC-003/AC-005 and trace portions of AC-007–AC-012/AC-019, including interruption, outage, duplicate/conflict and mixed log/trace resource scenarios. |
| E-14 | P8; E-13 reviewed and metric fixtures/stream/time/support/duplicate policies recorded | Replace metric printing with bounded local persistence and commit-backed responses. | Metric ingestion portions of AC-001–AC-003 and local-record AC-008; typed/nanosecond round-trip, restart and bounds. Numerical queries remain a separate packet. |
| E-15 | P8; E-14 reviewed | Add fixed gauge/rate/histogram queries over representative go-service metric payloads before dashboard presentation. | Metric query portions of AC-001, AC-006 and numerical profile fixtures for AC-024, including resets, gaps, temporality and incompatible histograms. |
| E-16 | P8; E-15 reviewed | Extend the existing Parquet/R2 pipeline, historical queries, eviction and retention to metrics. | Metric archived AC-003, historical/lookback AC-006 and metric portions of AC-007–AC-012/AC-019. Exercise all signals together and close remaining all-signal backend response, recovery and resource cases. |
| E-17 | P9; E-16 reviewed | Add catalog validation and protocol-specific Overview panels over verified fixed metric queries, with embedded licensed assets. | AC-023/AC-024: HTTP-only, gRPC-only, dual and worker entries; uncatalogued queries; units/aggregation labels; bounded charts; no-data/zero/stale states. |
| E-18 | P9; E-17 reviewed | Complete the existing MVC views, linked investigation, shareable absolute context, keyboard details, visible query/status outcomes and operator runbook. | Full AC-013/AC-015/AC-016/AC-022/AC-025 and remaining frontend AC-023/AC-024. No site login/session subsystem. |

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
| E-04 stable pagination | Choose timestamp tie-breaker, late-arrival behavior and cursor expiry for recent logs. Fixed absolute bounds, keyset pagination and a cursor receipt boundary are proposals to verify. Define and label actual text-search scope consistently. Preserve pagination across local/archive transitions in E-09. |
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
