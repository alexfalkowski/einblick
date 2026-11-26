# Implementation queue

[Requirements](requirements.md) own the product contract and open decisions.
This file contains feature implementation steps, dependencies, acceptance
coverage and saved progress. Agent workflow and engineering guidance live in
[AGENTS.md](../AGENTS.md).

## Continue from here

Say `Continue docs/review-and-plan.md`. Each continuation handles one step.

**Current step:** E-11 — Persist traces locally.

**Status:** ready.

**Next action:** After owner review of E-10, record the trace fixtures,
timestamp selection, supported shapes and duplicate policy for E-11.

### Resume context

- Use the daily log archive as a reference for trace and metric sizing. On
  real R2, the log worker archived 9,457 synthetic records as seven UTC-day
  files totaling 33.36 MB. With 250 mCPU and 512 MiB, the cold 7-day first
  page took 4.01 s and a full-range no-match search took 3.86 s. Account
  for file count and full-range reads when sizing the next signals.
- Preserve the [accepted DuckDB cancellation boundary](agents/accepted-design/archive.md#duckdb-remote-read-cancellation)
  when exercising remote reads and resource recovery.
- [Response byte budgeting and admission through response completion](agents/accepted-design/log-queries.md#response-work-after-repository-admission)
  remain deferred.
- [Early log disk backpressure](agents/accepted-design/archive.md#early-log-disk-backpressure)
  is deferred at the measured pilot load. The existing log intake returns
  retryable `Unavailable` when storage cannot commit an export. The focused
  `make features feature=features/logs/transport/grpc/logs.feature:103`
  scenario passed with earlier data intact.
- The 2026-11-23 production sample had 265 committed logs in 59 minutes with
  a 169-record burst in one minute. The 1 GiB database claim had 792 MiB
  available and the 2 GiB staging claim had 1,827 MiB available. The newer
  Kubernetes log file covered 13 minutes. Use these measurements with observed
  backlog growth and outage duration when revisiting the disk headroom policy.
- The disposable 24-hour replay used 7,364 records at five logs per minute
  with one burst of 169. Database and staging peak allocations were 13/10 MiB
  with 1 KiB bodies, 117/79 MiB with 8 KiB bodies and 271/312 MiB with 32 KiB
  bodies. The one-hour 8 KiB backlog drained in 90 s at the ten-second
  publish interval. A separate Parquet read verified all 464 records in nine
  objects. Keep capacity for publication metadata, checkpoints and recovery
  while intake is rejecting retries.
- For the archived trace and metric sizing gates, the log-only R2 sample
  reached 9,457 objects and 75.2 MB including metadata by 2026-11-23.
  Bucket requests for 2026-11-16 to 2026-11-23 were about 10,000 Class A and
  28,800 Class B. The account snapshot at 23:02 UTC had 74.7 MB of Standard
  storage and zero Infrequent Access bytes. A 30-day account request sample
  ending at 00:00 UTC on 2026-11-23 counted 5,699 Class A and 16,613 Class B
  requests before the final day of the bucket sample. The daily storage
  series was sparse while the archive grew. Measure the later billing window
  across the account when recalculating. [R2 pricing](https://developers.cloudflare.com/r2/pricing/)
- In the log archive sizing probe, 64 identical records under the 640 KiB
  batch target produced one 4,482-byte Parquet file. Adding 9,000-byte values
  to the shared resource and scope produced three files totaling 87,877 bytes.
  Upload and full-object verification bytes matched staged bytes. Idle
  next-day lookups took 0.7–7.9 ms with up to 64 retained records. Use these
  inputs when comparing trace and metric archive sizing.
- E-12 and E-17 extend the existing MVC site under `internal/site`. Follow the
  [Logs feature layout](../internal/site/logs) and reuse the
  [embedded catalogs](../internal/site/locales), [shared layouts](../internal/site/root/layout) and
  [Einblick daisyUI theme](../internal/site/static/logs.css). Use the
  [initial visual reference](requirements.md#87-service-catalog-and-standard-ux)
  and the [shared time controls](requirements.md#time-controls). Verify each
  view opens direct fixed-range links and reloads relative URLs against now.
  Include a reload after paging where the view paginates.
  E-18 owns connected browser navigation, full accessibility acceptance
  and historical query outcomes. With an HTTP transport timeout of `1ns`,
  a direct German `GET /logs` returned HTTP 504 with an empty body.
  Partial queries show a localized timeout when that response reaches htmx.

## 1. Remaining steps

| Unit | Phase / entry | Remaining deliverable | Evidence to close |
| --- | --- | --- | --- |
| E-11 | P7; E-10 reviewed and trace fixtures/time/support/duplicate policies recorded | Replace trace printing with bounded local persistence, preserving events/links and commit-backed responses. | Trace ingestion portions of AC-001–AC-003 and local-record AC-008; typed/nanosecond round-trip, restart and bounds. Query portions remain open until E-12. |
| E-12 | P7; E-11 reviewed | Expose fixed trace search and lookup through the v1 gRPC and HTTP RPC API. Add the multilingual MVC page at `/traces` with a bounded waterfall, span details and log correlation (WEB-017). | Trace queries through both API transports and the browser. Local cross-service/midnight AC-005, trace query portions of AC-001/AC-013/AC-015, trace AC-027 and explicit incomplete/large-trace/context outcomes. |
| E-13 | P7; E-12 reviewed | Extend the existing Parquet/R2 pipeline, historical queries, eviction and retention to traces. Move R2 store creation and DuckDB R2 setup from `internal/logs/archive.go` into shared startup wiring as traces begin using them. | Archived trace AC-003/AC-005 and trace portions of AC-007–AC-012/AC-019, including interruption, outage, duplicate/conflict and mixed log/trace resource scenarios. |
| E-14 | P8; E-13 reviewed and metric fixtures/stream/time/support/duplicate policies recorded | Replace metric printing with bounded local persistence and commit-backed responses. | Metric ingestion portions of AC-001–AC-003 and local-record AC-008; typed/nanosecond round-trip, restart and bounds. Numerical queries remain a separate packet. |
| E-15 | P8; E-14 reviewed | Add fixed gauge/rate/histogram queries over representative go-service metric payloads before dashboard presentation. | Metric query portions of AC-001, AC-006 and numerical profile fixtures for AC-024, including resets, gaps, temporality and incompatible histograms. |
| E-16 | P8; E-15 reviewed | Extend the existing Parquet/R2 pipeline, historical queries, eviction and retention to metrics. | Metric archived AC-003, historical/lookback AC-006 and metric portions of AC-007–AC-012/AC-019. Exercise all signals together and close remaining all-signal backend response, recovery and resource cases. |
| E-17 | P9; E-16 reviewed | Add catalog validation and protocol-specific Overview panels over verified fixed metric queries, with embedded licensed assets and localized controls/chart/status text (WEB-017). | AC-023/AC-024: HTTP-only, gRPC-only, dual and worker entries; uncatalogued queries; units/aggregation labels; bounded charts; no-data/zero/stale states; Overview AC-027. |
| E-18 | P9; E-17 reviewed | Complete the existing multilingual MVC views, linked investigation, shareable absolute context, keyboard details, visible query/status outcomes and operator runbook. | Full AC-013/AC-015/AC-016/AC-022/AC-025/AC-027 and remaining frontend AC-023/AC-024. No site login/session subsystem. |

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
| E-03/E-11/E-14 response and retry | Commit failure never produces success. Distinguish non-retried partial-success from retryable temporary failure. Define each signal's duplicate/conflict behavior and bounded duplicate horizon when adding its persistence, then exercise retries after archival/eviction for traces and metrics in E-13/E-16; avoid an indefinitely growing index. |
| E-03/E-11/E-14 recovery and compatibility | Reopen committed data and export state after interruption. Readiness waits for local recovery; R2 outage alone need not fail it. Close database users through the existing lifecycle and verify supported schema/runtime upgrades and rollback as each signal gains persistence. |
| Local schema changes at introduction | Extend the existing Goose history through numbered embedded migrations. Reject unsupported newer schemas; verify data-preserving upgrades, failed-migration recovery and the supported rollback behavior for each actual change under AC-017. |
| E-15/E-16 metric correctness | Hand-check rates and histogram results for two instances, resets/start times, gaps, temporality, duplicate points and incompatible buckets in E-15. Aggregate compatible distributions before quantiles; verify lookback across midnight and local/archive boundaries in E-16. |
| E-13/E-16 archive ownership | Preserve per-query source ownership and reader cleanup across publication and eviction for traces and metrics. |
| Resource bounds at introduction | Exercise ingestion, query, export and upload together when adding traces and metrics. Measure database/WAL, spill and completed-file allocation through repeated eviction and checkpoint cycles. Reserve space for metadata commits and backlog recovery when revisiting early disk backpressure under OPS-004. |
| R2 free-tier sizing | Use the log-only baseline in the resume context. Recalculate projected monthly usage for logs and traces in E-13, then for all three signals in E-16. Account for average daily peak storage and Class A and B operations from publication, retries, discovery, and reads. Include usage from other buckets on the account and compare the totals with the [current R2 Standard free tier](https://developers.cloudflare.com/r2/pricing/). |
| E-17/E-18 browser acceptance | Verify URL round-trip/return navigation, keyboard row/span access, bounded large traces, missing correlation and stale/partial/error/cancelled outcomes. Filter Overview traces to active instance/time scope; preserve search focus/caret/selection on refresh. The synthetic prototype leaves these behaviors unproven. |

## 4. Acceptance coverage

The table assigns evidence ownership for these feature steps; it does not mark a scenario passed.
Partial local/signal evidence is not full archive/all-signal acceptance.

| Acceptance | Planned evidence owner |
| --- | --- |
| AC-001 | Log durable intake in E-03 and queries in E-04; trace intake/query in E-11/E-12; metric intake/query in E-14/E-15. Receipt-only responses do not pass this scenario. |
| AC-002 | E-03/E-11/E-14 for signal support/responses and local admission failures; E-13/E-16 for trace and metric archive-outage capacity behavior. |
| AC-003 | Archived traces in E-11/E-13 and metrics in E-14/E-16. |
| AC-005 | E-12 local distributed trace; E-13 archived/midnight lookup. |
| AC-006 | E-15 numerical metric semantics; E-16 historical/lookback continuity. |
| AC-007 | Extend source overlap, publication and eviction queries to traces and metrics in E-13/E-16. |
| AC-008 | E-11/E-14 trace and metric committed-record recovery; extend export and publication recovery in E-13/E-16. |
| AC-009 | Extend local export and remote publication recovery for traces and metrics in E-13/E-16. |
| AC-010 | Repeat outage, visibility, capacity and backlog recovery checks for traces and metrics in E-13/E-16. Early log backpressure is deferred under OPS-004. |
| AC-011 | Verify fresh-volume trace and metric archive discovery and reads in E-13/E-16. |
| AC-012 | Extend retention, retry and expiration scenarios with trace and metric policies in E-13/E-16. |
| AC-013 | Trace and metric query coverage in E-12/E-13/E-15/E-16, browser completion in E-18. |
| AC-014 | Reserved; no v1 work. |
| AC-015 | E-12 adds trace rendering and correlation; E-18 completes navigation acceptance. |
| AC-016 | Extend outage and recovery coverage in E-13/E-16. E-18 completes visible frontend outcomes. |
| AC-017 | Check supported archive, schema and runtime upgrade and rollback paths when adding trace and metric persistence and archival. |
| AC-018 | E-11/E-14 trace and metric recovery, shutdown and database reopen. Deployed runtime validation is owned by the operator. |
| AC-019 | Complete-batch eviction and cleanup for traces and metrics in E-13/E-16. |
| AC-021 | E-12/E-13/E-15/E-16 DuckDB query review and E-13/E-16 immutable export review. Preserve the shared CGO build default with each change. |
| AC-022 | E-18 full browser-workflow evidence without site credentials or sessions. |
| AC-023 | E-17 catalog behavior and uncatalogued queries, completed frontend evidence in E-18. |
| AC-024 | E-15 verified profile/numerical fixtures, E-16 historical continuity, E-17 charts and bounded states. |
| AC-025 | E-18 connected investigation, links, selections, keyboard details and explicit trace scope. |
| AC-026 | Repeat resource checks with trace and metric archive support in E-13/E-16. |
| AC-027 | E-12 trace views; E-17 Overview; E-18 complete navigation, accessibility and error/status language coverage. Follow WEB-017 and reuse the Logs page full and partial language scenarios. |
