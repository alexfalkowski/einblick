# Implementation queue

[Requirements](requirements.md) own the product contract and open decisions.
This file contains feature implementation steps, dependencies, acceptance
coverage and saved progress. Agent workflow and engineering guidance live in
[AGENTS.md](../AGENTS.md).

## Continue from here

Say `Continue docs/review-and-plan.md`. Each continuation handles one step.

**Current step:** E-09 — Add log retention and verify outage and resource recovery.

**Status:** blocked on owner review of E-08.

**Next action:** After owner review of [E-08](https://github.com/alexfalkowski/einblick/pull/47),
resolve [O-003](requirements.md#15-open-decision-register) and implement local
query availability, expiration handling and backlog recovery.

### Resume context

- Local retention uses receipt age and keeps complete batches until publication
  and cleanup are confirmed. Historical queries use the durable eviction
  marker to identify expected archive objects. Under the current append-only
  lookup, a missing expected object is unavailable. E-09 must distinguish
  intentional expiration from failure under the selected retention policy.
  See [historical log availability](operations.md#-historical-log-availability).
- For AC-010, prefer an explicit local-only search that labels its coverage.
  A fresh volume can lack archived rows within any selected event-time
  window. Complete queries continue to require archive discovery.
- For O-003, prefer the existing Infraops object-age lifecycle. Confirm how
  Einblick recognizes that a missing object is past its retention guarantee,
  including when the bucket's policy changes.
- Preserve the [accepted DuckDB cancellation boundary](agents/accepted-design/archive.md#duckdb-remote-read-cancellation)
  when exercising remote reads and resource recovery.
- [Response byte budgeting and admission through response completion](agents/accepted-design/log-queries.md#response-work-after-repository-admission)
  remain deferred.
- E-11 and E-16 extend the existing MVC site under `internal/site`. Follow the
  [Logs feature layout](../internal/site/logs) and reuse the
  [embedded catalogs](../internal/site/locales), [shared layouts](../internal/site/root/layout) and
  [Einblick daisyUI theme](../internal/site/static/logs.css). Use the
  [initial visual reference](requirements.md#87-service-catalog-and-standard-ux).
  E-17 still owns connected browser navigation, full accessibility acceptance
  and historical query outcomes. With an HTTP transport timeout of `1ns`,
  a direct German `GET /logs` returned HTTP 504 with an empty body.
  Partial queries show a localized timeout when that response reaches htmx.

## 1. Remaining steps

| Unit | Phase / entry | Remaining deliverable | Evidence to close |
| --- | --- | --- | --- |
| E-09 | P6; E-08 reviewed and O-003 retention meaning selected | Add log retention and verify late/skew/retry policies, R2 outage/backpressure/backlog recovery and repeated concurrent resource/disk cycles. | Log AC-010/AC-012/AC-019 and measured bounds/health/recovery. Measure idle archive scans and how shared OTLP context affects staged bytes, R2 object count, upload bytes, and verification bytes. |
| E-10 | P7; E-09 reviewed and trace fixtures/time/support/duplicate policies recorded | Replace trace printing with bounded local persistence, preserving events/links and commit-backed responses. | Trace ingestion portions of AC-001–AC-003 and local-record AC-008; typed/nanosecond round-trip, restart and bounds. Query portions remain open until E-11. |
| E-11 | P7; E-10 reviewed | Add fixed trace search/lookup, bounded waterfall/details and log correlation in the existing multilingual MVC application (WEB-017). | Local cross-service/midnight AC-005, trace query portions of AC-001/AC-013/AC-015, trace AC-027 and explicit incomplete/large-trace/context outcomes. |
| E-12 | P7; E-11 reviewed | Extend the existing Parquet/R2 pipeline, historical queries, eviction and retention to traces. Move R2 store creation and DuckDB R2 setup from `internal/logs/archive.go` into shared startup wiring as traces begin using them. | Archived trace AC-003/AC-005 and trace portions of AC-007–AC-012/AC-019, including interruption, outage, duplicate/conflict and mixed log/trace resource scenarios. |
| E-13 | P8; E-12 reviewed and metric fixtures/stream/time/support/duplicate policies recorded | Replace metric printing with bounded local persistence and commit-backed responses. | Metric ingestion portions of AC-001–AC-003 and local-record AC-008; typed/nanosecond round-trip, restart and bounds. Numerical queries remain a separate packet. |
| E-14 | P8; E-13 reviewed | Add fixed gauge/rate/histogram queries over representative go-service metric payloads before dashboard presentation. | Metric query portions of AC-001, AC-006 and numerical profile fixtures for AC-024, including resets, gaps, temporality and incompatible histograms. |
| E-15 | P8; E-14 reviewed | Extend the existing Parquet/R2 pipeline, historical queries, eviction and retention to metrics. | Metric archived AC-003, historical/lookback AC-006 and metric portions of AC-007–AC-012/AC-019. Exercise all signals together and close remaining all-signal backend response, recovery and resource cases. |
| E-16 | P9; E-15 reviewed | Add catalog validation and protocol-specific Overview panels over verified fixed metric queries, with embedded licensed assets and localized controls/chart/status text (WEB-017). | AC-023/AC-024: HTTP-only, gRPC-only, dual and worker entries; uncatalogued queries; units/aggregation labels; bounded charts; no-data/zero/stale states; Overview AC-027. |
| E-17 | P9; E-16 reviewed | Complete the existing multilingual MVC views, linked investigation, shareable absolute context, keyboard details, visible query/status outcomes and operator runbook. | Full AC-013/AC-015/AC-016/AC-022/AC-025/AC-027 and remaining frontend AC-023/AC-024. No site login/session subsystem. |

Each step includes its configuration, dependencies and service-boundary
acceptance. Trace and metric storage/query contracts and full recovery/archive
evidence follow in P7/P8.

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
| E-03/E-10/E-13 response and retry | Commit failure never produces success. Distinguish non-retried partial-success from retryable temporary failure. Define each signal's duplicate/conflict behavior and bounded duplicate horizon when adding its persistence, then exercise retries after archival/eviction in E-09/E-12/E-15; avoid an indefinitely growing index. |
| E-03/E-10/E-13 recovery and compatibility | Reopen committed data and export state after interruption. Readiness waits for local recovery; R2 outage alone need not fail it. Close database users through the existing lifecycle and verify supported schema/runtime upgrades and rollback as each signal gains persistence. |
| Local schema changes at introduction | Extend the existing Goose history through numbered embedded migrations. Reject unsupported newer schemas; verify data-preserving upgrades, failed-migration recovery and the supported rollback behavior for each actual change under AC-017. |
| E-14/E-15 metric correctness | Hand-check rates and histogram results for two instances, resets/start times, gaps, temporality, duplicate points and incompatible buckets in E-14. Aggregate compatible distributions before quantiles; verify lookback across midnight and local/archive boundaries in E-15. |
| E-12/E-15 archive ownership | Preserve per-query source ownership and reader cleanup across publication and eviction for traces and metrics. |
| Resource bounds at introduction | Exercise ingestion, query, export and upload together in E-09 and repeat when adding traces and metrics. Measure database/WAL, spill and completed-file allocation through repeated eviction and checkpoint cycles. Reserve space for metadata commits and backlog recovery. |
| R2 free-tier sizing | Establish the log-only baseline in E-09. Recalculate projected monthly usage for logs and traces in E-12, then for all three signals in E-15. Account for average daily peak storage and Class A and B operations from publication, retries, discovery, and reads. Include usage from other buckets on the account and compare the totals with the [current R2 Standard free tier](https://developers.cloudflare.com/r2/pricing/). |
| E-16/E-17 browser acceptance | Verify URL round-trip/return navigation, keyboard row/span access, bounded large traces, missing correlation and stale/partial/error/cancelled outcomes. Filter Overview traces to active instance/time scope; preserve search focus/caret/selection on refresh. The synthetic prototype leaves these behaviors unproven. |

## 4. Acceptance coverage

The table assigns evidence ownership for these feature steps; it does not mark a scenario passed.
Partial local/signal evidence is not full archive/all-signal acceptance.

| Acceptance | Planned evidence owner |
| --- | --- |
| AC-001 | Log durable intake in E-03 and queries in E-04; trace intake/query in E-10/E-11; metric intake/query in E-13/E-14. Receipt-only responses do not pass this scenario. |
| AC-002 | E-03/E-10/E-13 for signal support/responses and local admission failures; E-09/E-12/E-15 for archive-outage capacity behavior. |
| AC-003 | Archived traces in E-10/E-12 and metrics in E-13/E-15. |
| AC-005 | E-11 local distributed trace; E-12 archived/midnight lookup. |
| AC-006 | E-14 numerical metric semantics; E-15 historical/lookback continuity. |
| AC-007 | Extend source overlap, publication and eviction queries to traces and metrics in E-12/E-15. |
| AC-008 | E-10/E-13 trace and metric committed-record recovery; extend export and publication recovery in E-12/E-15. |
| AC-009 | Extend local export and remote publication recovery for traces and metrics in E-12/E-15. |
| AC-010 | E-09 log outage, visibility, backpressure and backlog recovery; repeat for traces/metrics in E-12/E-15. |
| AC-011 | Verify fresh-volume trace and metric archive discovery and reads in E-12/E-15. |
| AC-012 | E-09 log policy, retry and expiration scenarios; extend with trace and metric policies in E-12/E-15. |
| AC-013 | Log outage coverage in E-09, trace/metric query coverage in E-11/E-12/E-14/E-15, browser completion in E-17. |
| AC-014 | Reserved; no v1 work. |
| AC-015 | E-11 adds trace rendering and correlation; E-17 completes navigation acceptance. |
| AC-016 | Log outage and recovery in E-09, extended in E-12/E-15. E-17 completes visible frontend outcomes. |
| AC-017 | Check supported archive, schema and runtime upgrade and rollback paths when adding trace and metric persistence and archival. |
| AC-018 | E-10/E-13 trace and metric recovery, shutdown and database reopen. Deployed runtime validation is owned by the operator. |
| AC-019 | E-09 log expiration and workspace cycles, then complete-batch eviction and cleanup for traces and metrics in E-12/E-15. |
| AC-021 | E-11/E-12/E-14/E-15 DuckDB query review and E-12/E-15 immutable export review. Preserve the shared CGO build default with each change. |
| AC-022 | E-17 full browser-workflow evidence without site credentials or sessions. |
| AC-023 | E-16 catalog behavior and uncatalogued queries, completed frontend evidence in E-17. |
| AC-024 | E-14 verified profile/numerical fixtures, E-15 historical continuity, E-16 charts and bounded states. |
| AC-025 | E-17 connected investigation, links, selections, keyboard details and explicit trace scope. |
| AC-026 | Repeat resource checks with trace and metric archive support in E-12/E-15. |
| AC-027 | E-11 trace views; E-16 Overview; E-17 complete navigation, accessibility and error/status language coverage. Follow WEB-017 and reuse the Logs page full and partial language scenarios. |
