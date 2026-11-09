# Remaining implementation plan

[Requirements](requirements.md) own the product contract and open decisions.
This plan owns the remaining packets, dependencies and acceptance coverage.
The service scaffold, name/module and CGO opt-in already exist. Telemetry
implementation and installation remain outstanding.

## Start here

Read the relevant requirements and acceptance scenarios, then select one packet
within the current request. Start P0 with E-01's source/fixture/platform inputs
and E-02's feasibility checks. Inspect existing code before planning baseline work.

Work serially through P0–P4, one packet and writable repository at a time. Resolve
routine details from supported source conventions; distinguish proposals from
agreed choices and update affected requirements/acceptance when decisions change.
Only material choices needed by the selected packet block it.

Follow each owning repository's instructions and command conventions. Read-only
references do not authorize sibling edits. Publishing, activation/deployment and
client enablement need explicit task scope. Stop at the selected packet's review
boundary; dependency completion does not activate its consumer. Follow the active
runtime's delegation rules.

For UI packets, use the [initial design reference](requirements.md#87-service-catalog-and-standard-ux).
Preserve that visual starting point and iterate in the working MVC service with
real data. The HTML and screenshots are references; no prototype server or
separate prototype development is needed.

Hand the scoped change, actual validation results and original patch to the human
for refinement and PR work. At that handoff, follow [phase feedback](phase-feedback.md)
for requirements, patch/base, actual session ID and final PR capture. The owner
selects the next phase after product and feedback review.

For documentation changes, run from the repository root with Python 3:

```sh
python3 tools/check_handoff.py
```

This checks local Markdown targets, requirement/acceptance references and embedded
preview assets/license, and prints results without storing a report. Links into
uninitialized Git submodules are reported as skipped. Use the [README](../README.md)
and `make help` for service checks; real frontend acceptance belongs to its packets.

## 1. Service packets

Each row is a review boundary. Keep implementation, relevant validation and docs
together. Resolve routine details from the supported source conventions and
[OTel contracts](requirements.md#11-inherit-standards-and-derive-routine-details).
Material unresolved choices block only the packet that depends on them.

| Unit | Phase / entry | Remaining deliverable | Evidence to close |
| --- | --- | --- | --- |
| E-01 | P0 | Inspect supported go-service instrumentation/OTel versions and repository conventions. Establish required platforms (O-010), support/fixture inputs (O-006/O-012), and residual time/duplicate policies (O-004/O-005). | References/version inventory, representative fixture needs, support differences and platform inputs sufficient for E-02. No exhaustive schema or later-phase design package. |
| E-02 | P0; E-01 inputs and test-R2 access for remote checks | Integrate pinned DuckDB/engine/extensions and a lean S3 client into the existing scaffold; establish native/R2 feasibility before production intake. | All-signal typed/nanosecond DuckDB → Parquet → Go round-trip, restart, packaged extensions in final required-platform images, constrained process memory, actual R2 transfer/reconciliation/cancellation/pagination/multipart operations and separate DuckDB remote reads. License/runtime dependencies and linked-binary delta for AC-026. |
| E-03 | P1; E-02 passed and log time/support/duplicate policies recorded | Bounded standard log intake → local commit → stable fixed query → thin MVC Logs page. Include diagnostics, migration baseline, shutdown/reopen and backpressure. | Log portions of AC-001–AC-003, AC-004, local-record AC-008 and backend bounds/cancellation in AC-013. No other signals or archive eviction. |
| E-04 | P1; E-03 reviewed and trace policies recorded | Trace intake/storage, events/links, fixed search/lookup, bounded waterfall/details and log correlation. | Trace portions of AC-001–AC-003, local cross-service/midnight AC-005, recovery and explicit incomplete/large-trace/context outcomes. |
| E-05 | P1; E-04 reviewed and metric fixtures/stream/duplicate policies available | Metric intake and fixed gauge/rate/histogram queries before full dashboard presentation. | Metric portions of AC-001–AC-003, AC-006, numerical profile fixtures for AC-024, local recovery for every signal and remaining P1 response/support cases. |
| E-06 | P2; E-05 reviewed and immutable membership/recovery transitions designed | Durable batch/export schema, completed local Parquet files, content identity and interrupted-export/workspace recovery. | Archive-format AC-003, local-export AC-009 and pending-job AC-008. No source deletion or uploadable partial files. |
| E-07 | P2; E-06 reviewed and E-02 actual-R2 evidence | Job-driven bounded upload/retry, content verification, ambiguous-outcome reconciliation and durable publication state. | Remote AC-008/AC-009, transfer bounds and AC-026 integration. Keep local source rows until E-08. |
| E-08 | P2; E-07 reviewed and source/reader ownership designed | Selected-day discovery, DuckDB historical reads, local/archive source selection, safe eviction and fresh-volume discovery. | AC-007/AC-011, eviction/cleanup AC-019, archived AC-003/AC-005, metric lookback continuity and historical failure/cancellation in AC-013/AC-016. |
| E-09 | P2; E-08 reviewed and O-003 retention meaning selected | Retention, late/skew/retry scenarios, R2 outage/backpressure/backlog recovery and repeated concurrent resource/disk cycles. | AC-010/AC-012/AC-019 and measured bounds/health/recovery. Infrastructure lifecycle activation is I-02 work. |
| E-10 | P3; E-05 correctness and E-09 historical/resource evidence reviewed | Catalog validation and protocol-specific Overview panels over verified fixed metric queries, with embedded licensed assets. | AC-023/AC-024: HTTP-only, gRPC-only, dual and worker entries; uncatalogued queries; units/aggregation labels; bounded charts; no-data/zero/stale states. |
| E-11 | P3; E-10 reviewed | Complete the existing MVC views, linked investigation, shareable absolute context, keyboard details, visible query/status outcomes and operator runbook. | Full AC-013/AC-015/AC-016/AC-022/AC-025 and remaining frontend AC-023/AC-024. No site login/session subsystem. |

Use these smaller packets for E-02 and E-03; the parent closes after all its
evidence is complete:

| Packet | Principal result |
| --- | --- |
| E-02a | Final pinned native path, persistent typed/nanosecond round-trip, restart and packaged extensions on required release platforms. Reuse the existing `static=0` interface. |
| E-02b | Actual-R2 lean-client operations and DuckDB remote reads with cancellation, reconciliation, bounded resources and dependency/binary measurements. |
| E-02c | Integrate the validated dependencies/configuration into the existing go-service composition and record supported commands/results. |
| E-03a | Bounded log intake, commit acknowledgement, stable query, recovery, response and cancellation behavior. |
| E-03b | Thin MVC Logs view over that query path with safe rendering. |

E-03/E-04 establish the single MVC implementation that P3 completes. The E-02
feasibility harness does not replace later service-boundary acceptance scenarios.
An unavailable R2 resource blocks E-02b; incomplete actual-R2 or required-platform
evidence prevents P0 completion.

## 2. Infrastructure packets

Reuse existing CGO, persistent-storage, R2 bucket/expiration and storage-aware
release tooling. Their interfaces are summarized in
[requirements section 6](requirements.md#6-existing-integration-surfaces).
No shared capability implementation or generic CGO trial is scheduled.
Use existing rolling updates; do not add Recreate or a strategy selector (D-018).

| Unit | Phase / entry | Remaining scope | Evidence and boundary |
| --- | --- | --- | --- |
| I-02 | P0 test access as needed; P4 final policy/configuration | Identify a usable private test bucket/reference and credential sources for E-02. Configure installation bucket/reference and selected retention policy after O-003 is resolved. | Owning CF checks/previews and actual intended-permission access. No public archive domain. Review complete lifecycle-rule ownership and explicit remote disabling under LIF-002. Production retention selection is not a prerequisite for a test bucket. Separate definitions/previews from activation. |
| I-03 | P4; E-11 reviewed, I-02 ready, O-001/O-002/O-007 resolved and storage-preserving release execution verified | Configure einblick identity/ingress, immutable native image, storage capacity/path/profile, one replica with existing rolling updates, resources, internal gRPC, browser HTTP, secrets/TLS/trust, probes and lifecycle budgets. | Owning apps/CF previews and release/configuration preservation. Prepare configuration separately from activating merge/deployment. Actual CSI permissions, claim lifecycle, graceful close, overlapping startup/lock handoff and readiness remain deployment gates under AC-018. |

Read the owning repository's instructions, Makefile and CI before selecting its
current validation commands. Previews and resource activation can require
provider credentials and remote state. Account for automatic application of
configuration on merge; preparation alone does not authorize that activation.

## 3. Design checks at implementation gates

These checks retain the unresolved constraints behind the packets. Document the
relevant choices with the implementing patch; later designs do not block E-01.

| Gate | Required design or scenario |
| --- | --- |
| E-01/E-02 source fixtures | One representative export per signal, actual resource/scope/instance identity and instrumentation versions. Include gzip/empty/unsupported requests, nested typed values/large integers, nanoseconds, correlated/uncorrelated logs, cross-service/midnight spans with events/links, and cumulative/delta/reset/gap/histogram metrics. Label manufactured edge cases as synthetic. |
| E-02 native image | Pin driver, bundled engine and extension versions/licenses. Verify actual timestamp binding, packaged extension loading without runtime internet installation, required native libraries, image scans, non-root/read-only-root operation and process memory. A host CLI run does not establish image behavior. |
| E-03–E-05 response and retry | Commit failure never produces success. Distinguish non-retried partial-success from retryable temporary failure. Define per-signal duplicate/conflict behavior and bounded duplicate horizon, including retry after archival/eviction; avoid an indefinitely growing index. |
| E-03 stable pagination | Choose timestamp tie-breaker, late-arrival behavior, cursor expiry and local/archive continuity. Fixed absolute bounds, keyset pagination and a cursor receipt boundary are proposals to verify. Define and label actual text-search scope consistently. |
| E-05 metric correctness | Hand-check rates and histogram results for two instances, resets/start times, gaps, temporality, duplicate points and incompatible buckets. Aggregate compatible distributions before quantiles; verify lookback across midnight and local/archive boundaries in E-08. |
| E-06–E-08 archive ownership | Define durable batch transitions, immutable source membership, expected content identity, interrupted-transition recovery, per-query source ownership and reader cleanup lifetime. Cover upload success before local marking and derivative regeneration whose Parquet bytes may differ. Preserve a usable source through publication/eviction; query-time DISTINCT is insufficient. |
| E-03/E-08/E-09 resource bounds | Bound decode/decompression, query scan/range/results, cancellation, native/Go memory, upload buffers and workspace. Exercise ingestion/query/export/upload together. Measure database/WAL, spill and completed-file allocation through repeated eviction/checkpoint cycles; deleted rows do not prove reclaimed disk. Reserve space for metadata commits and backlog recovery. |
| E-10/E-11 browser acceptance | Verify URL round-trip/return navigation, keyboard row/span access, bounded large traces, missing correlation and stale/partial/error/cancelled outcomes. Filter Overview traces to active instance/time scope; preserve search focus/caret/selection on refresh. The synthetic prototype leaves these behaviors unproven. |
| I-03 storage/release | Preserve stable PVC identity and optional-profile presence through version updates for einblick and other apps. Choose reclaim/backup arrangements and validate actual non-root volume writes. Protected claims and ReadWriteOnce do not enforce one database writer. |
| I-03 listeners/lifecycle | Align actual listeners, probes, Services and ingress; HTTP 8080/internal gRPC 9090 are proposed installation conventions. Readiness waits for local recovery; R2 outage alone need not fail it. Stop intake/users and close DuckDB within termination grace; bound replacement lock waits. |

## 4. Phase order and pilot

1. P0: E-01 → I-02 test-access portion if needed → E-02.
2. P1: E-03 → E-04 → E-05.
3. P2: E-06 → E-07 → E-08 → E-09.
4. P3: E-10 → E-11.
5. P4: verify storage-preserving release execution → I-02 final configuration →
   I-03 → preflight → authorized installation validation → one-client pilot.

Before installation, review supported schema/runtime upgrade and rollback
(AC-017), architectural constraints (AC-021), all active acceptance portions and
the recovery runbook. Keep installation, runtime validation and client enablement
separately reviewable. Set the pilot observation window and stop/rollback criteria
before enabling the client. The client's actual runtime-config owner applies explicit
logger/metrics/tracer endpoints, interval, sampling and TLS/authentication.

The pilot closes AC-020 and refines O-008 with observed signal rates, retained
bytes, peak process memory, disk growth, archive lag/outage reserve, backlog drain
and recent/historical query timings. Verify same-volume replacement and
archived-only recovery with a fresh volume. Document single-instance downtime
and loss of unarchived data after permanent volume loss. Broader rollout requires
a later owner decision.

## 5. Acceptance coverage

Record actual commands/scenarios, dependency revisions, measured constraints,
policy choices, interruption/upgrade/rollback results and remaining limitations
with each packet. The table assigns evidence ownership; it does not mark a
scenario passed. Partial local/signal evidence is not full archive/all-signal
acceptance.

| Acceptance | Planned evidence owner |
| --- | --- |
| AC-001 | Signal slices E-03/E-04/E-05, with all-three-signal completion after E-05. |
| AC-002 | E-03/E-04/E-05 for signal support/responses; E-09 for capacity behavior. |
| AC-003 | Local typed/precision evidence in E-02–E-05; Parquet in E-06; full archived query in E-08. |
| AC-004 | E-03 ordering/pagination, repeated across local/archive transitions in E-08. |
| AC-005 | E-04 local distributed trace; E-08 archived/midnight lookup. |
| AC-006 | E-05 numerical metric semantics; E-08 for historical/lookback continuity. |
| AC-007 | E-08 actual overlap/publication/eviction queries. |
| AC-008 | E-03–E-05 committed-record recovery; E-06/E-07 pending-export recovery. |
| AC-009 | E-06 interrupted local export; E-07 ambiguous remote publication. |
| AC-010 | E-09 outage, visibility, backpressure and backlog recovery. |
| AC-011 | E-08 fresh-volume archive discovery and reads. |
| AC-012 | E-09 policy/retry/expiration scenarios, using the policies recorded for E-03–E-05. |
| AC-013 | Bounds/cancellation from E-03 onward, historical work in E-08/E-09, browser completion in E-11. |
| AC-014 | Reserved; no v1 work. |
| AC-015 | E-03/E-04 establish safe rendering/correlation; E-11 completes navigation acceptance. |
| AC-016 | E-03 independent diagnostics; E-08/E-09 backend coverage/failure/recovery; E-11 visible frontend outcomes. |
| AC-017 | Migration/rollback design from E-03, archive/schema evidence from E-06/E-08, full supported upgrade rehearsal in P4 preflight. |
| AC-018 | E-02 native release evidence; I-03 configuration and release-tooling-preservation evidence; graceful close, lock handoff and readiness under the existing rolling-update path; actual CSI/rollout/runtime validation in P4. Source interfaces alone do not pass this scenario. |
| AC-019 | E-06 derivative cleanup, E-08 safe complete-batch eviction, E-09 expiration/workspace cycles. |
| AC-020 | P4 one-client pilot and measured report. |
| AC-021 | E-02 consuming build/default review, E-05/E-08 DuckDB query review, E-06/E-07 immutable export review; close applicable review items in P4 preflight. |
| AC-022 | E-11 no site credential/session dependency. |
| AC-023 | E-10 catalog behavior and uncatalogued queries, completed frontend evidence in E-11. |
| AC-024 | E-05 verified profile/numerical fixtures, E-08 historical continuity, E-10 charts and bounded states. |
| AC-025 | E-11 connected investigation, links, selections, keyboard details and explicit trace scope. |
| AC-026 | E-02 actual-R2/dependency/binary/resource evidence, E-07 durable transfer integration, final evidence review in P4 preflight. |
