# Implementation queue

[Requirements](requirements.md) own the product contract and open decisions.
This file owns the remaining steps, saved progress, dependencies, acceptance
coverage and handoff process. It is the single file used to drive implementation.
The service scaffold, name/module and CGO opt-in already exist. Telemetry
implementation and installation remain outstanding.

## Continue from here

Say `Continue docs/review-and-plan.md`. In the same conversation, `continue` is
enough. Each request works on exactly one step, then stops.

**Current step:** E-01 — Receive and print logs.

**Status:** ready.

**Resume notes:** Not started. Inspect the existing server and log source
contract, then receive a local client's OTLP/gRPC logs and print them.

**Last completed step:** None.

The implementing agent follows this loop:

1. Read this saved state and the first row in **Remaining steps**. Resume that
   step if it is already in progress or blocked; do not skip to later work.
   Verify the repository state and recorded prerequisites before proceeding.
2. Set the status to `in progress`. Read the relevant requirements, repository
   instructions and source conventions, then implement only this step with its
   validation and documentation. Routine details belong with the implementation.
3. If work is interrupted or validation fails, keep the step in the queue. Save
   actual commands/results, remaining work and any blocker in the resume notes.
   Set the status to `in progress` or `blocked` as appropriate. The next
   continuation resumes the same step.
4. When its exit evidence and applicable phase checks are satisfied, preserve
   the original patch/base and record concise validation, acceptance and handoff
   references under **Completion evidence**. Follow **Patch handoff and feedback**
   below; identify missing evidence without inventing it.
5. Remove the completed row from **Remaining steps**. Update the current step to
   the new first row, set its status to `ready`, replace the resume notes and
   update the last completed step. Report the finished step and what comes next,
   then stop. Do not implement the next row in the same request.
6. When the queue is empty and all readiness gates have passed, preserve final
   acceptance/recovery evidence in the delivered documentation, delete this plan
   and update incoming links in the same change. The product specification stays.

Only the **Remaining steps** table controls execution order. Completion evidence
is a compact record, not a second task list. Requirements and the later tables
provide reference material; the human does not need to choose between them.

Work serially through P0–P10, one step and writable repository at a time.
Distinguish proposals from agreed choices and update affected requirements and
acceptance when decisions change.
Only material choices needed by the selected packet block it.

P0 is development-only: records are discarded after printing, responses prove
receipt rather than durability, and the receiver's own OTLP log exporter must be
disabled to prevent a feedback loop. Do not enable a deployed client or claim
ING-002/AC-001 acceptance. P1 replaces print-only handling with commit-backed
ingestion; no permanent discard mode or second storage backend is required.

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
for refinement and PR work. A subsequent continuation request selects the next
ready step. At phase boundaries, review product/feedback evidence or record its
missing-evidence limitations before advancing; unmet product gates still block.

For documentation changes, run from the repository root with Python 3:

```sh
python3 tools/check_handoff.py
```

This checks local Markdown targets, requirement/acceptance references and embedded
preview assets/license, and prints results without storing a report. Links into
uninitialized Git submodules are reported as skipped. Use the [README](../README.md)
and `make help` for service checks; real frontend acceptance belongs to its packets.

## 1. Remaining steps

The first row is the current step. Each row is a separate review boundary; remove
it only after completion and handoff. Keep implementation, validation and docs
together. Resolve routine details from supported source conventions and
[OTel contracts](requirements.md#11-inherit-standards-and-derive-routine-details).
Material unresolved choices block only the packet that depends on them.

| Unit | Phase / entry | Remaining deliverable | Evidence to close |
| --- | --- | --- | --- |
| E-01 | P0 | Inspect supported go-service log instrumentation/OTel versions and server conventions, register the standard log receiver, bound request handling and print incoming records. Keep the receiver's own OTLP log exporter disabled. | A representative local client, including gzip, produces recognizable log content in server output. Record the development-only receipt response and limits. No database, queries, archive, trace/metric fixtures or deployment work. |
| E-02 | P1; E-01 reviewed | Pin and integrate DuckDB/engine into the existing composition and `static=0` build. Confirm required platforms and local persistent-file configuration. | Typed/nanosecond log round-trip and reopen; required-platform native service images, licenses/runtime dependencies and bounded process memory. Package extensions needed for this local path. Parquet and remote extensions are checked when introduced. No S3 dependency or R2 access. |
| E-03a | P1; E-02 reviewed and log time/support/duplicate policies recorded | Replace print-only handling with bounded log transactions and commit acknowledgement. Include diagnostics, migration baseline, shutdown/reopen, commit-failure responses and disk backpressure. | Log ingestion/support portions of AC-002/AC-003 and committed-record AC-008. Accepted records survive restart on the intact local data path. No query or browser requirement yet; AC-001 remains open. |
| E-03b | P2; E-03a reviewed | Add fixed recent-log queries with stable ordering/pagination, documented search/time scope, bounded work and cancellation. | Log AC-001/AC-004 and backend bounds/cancellation in AC-013. Read back acknowledged records, including after restart. No browser or R2 dependency. |
| E-03c | P2; E-03b reviewed | Add the thin MVC Logs page over the existing query path with safe rendering and visible loading/empty/error states. | Log rendering in AC-015, initial frontend portions of AC-013/AC-016/AC-022 and a useful local log investigation. No dashboard, trace view or login subsystem. |
| E-06 | P3; E-03c reviewed and log archive-day/membership/recovery policies recorded | Add durable log batch/export jobs, completed local Parquet files, content identity and interrupted-export/workspace recovery. | Log archive-format AC-003, local-export AC-009, pending-job AC-008 and derivative cleanup in AC-019. Verify typed/nanosecond Parquet round-trip and packaging. No R2 access, source deletion or uploadable partial files. |
| I-02-test | P4; E-06 reviewed | Identify a usable private test bucket/reference and credential source for E-07a. Inspect existing resources first; any provisioning/configuration change needs scope in its owning repository. | Actual intended-permission access, with no public archive domain. Production retention selection is not a prerequisite for a test bucket. Save verified references without exposing secrets. |
| E-07a | P4; I-02-test reviewed | Evaluate and integrate the lean S3 client and packaged DuckDB remote-read extensions. Check actual R2 operations before adding production upload jobs. | AC-026 dependency/binary/resource evidence and actual upload/download/list/HEAD/delete, cancellation, reconciliation, pagination and multipart checks; separate DuckDB remote reads on required-platform service images. Log batches are sufficient at this gate. |
| E-07b | P4; E-07a reviewed | Add job-driven bounded upload/retry, content verification, ambiguous-outcome reconciliation and durable publication state for completed log batches. | Log remote AC-008/AC-009 and durable-transfer AC-026 integration. Keep local source rows until E-08; successful intake still depends only on local commit. |
| E-08 | P5; E-07b reviewed and source/reader ownership designed | Add selected-day discovery, DuckDB historical log reads, local/archive source selection, safe eviction and fresh-volume discovery. | Log AC-007/AC-011, eviction/cleanup AC-019, archived log AC-003 and historical failure/cancellation in AC-013/AC-016. Traces and metrics are not prerequisites. |
| E-09 | P6; E-08 reviewed and O-003 retention meaning selected | Add log retention and verify late/skew/retry policies, R2 outage/backpressure/backlog recovery and repeated concurrent resource/disk cycles. | Log AC-010/AC-012/AC-019 and measured bounds/health/recovery. Infrastructure lifecycle activation is I-02 work. |
| E-04a | P7; E-09 reviewed and trace fixtures/time/support/duplicate policies recorded | Add bounded trace intake and local persistence, preserving events/links and commit-backed responses. | Trace ingestion portions of AC-001–AC-003 and local-record AC-008; typed/nanosecond round-trip, restart and bounds. Query portions remain open until E-04b. |
| E-04b | P7; E-04a reviewed | Add fixed trace search/lookup, bounded waterfall/details and log correlation in the existing MVC application. | Local cross-service/midnight AC-005, trace query portions of AC-001/AC-013/AC-015 and explicit incomplete/large-trace/context outcomes. |
| E-04c | P7; E-04b reviewed | Extend the existing Parquet/R2 pipeline, historical queries, eviction and retention to traces. | Archived trace AC-003/AC-005 and trace portions of AC-007–AC-012/AC-019, including interruption, outage, duplicate/conflict and mixed log/trace resource scenarios. |
| E-05a | P8; E-04c reviewed and metric fixtures/stream/time/support/duplicate policies recorded | Add bounded metric intake and local persistence with commit-backed responses. | Metric ingestion portions of AC-001–AC-003 and local-record AC-008; typed/nanosecond round-trip, restart and bounds. Numerical queries remain a separate packet. |
| E-05b | P8; E-05a reviewed | Add fixed gauge/rate/histogram queries over representative go-service metric payloads before dashboard presentation. | Metric query portions of AC-001, AC-006 and numerical profile fixtures for AC-024, including resets, gaps, temporality and incompatible histograms. |
| E-05c | P8; E-05b reviewed | Extend the existing Parquet/R2 pipeline, historical queries, eviction and retention to metrics. | Metric archived AC-003, historical/lookback AC-006 and metric portions of AC-007–AC-012/AC-019. Exercise all signals together and close remaining all-signal backend response, recovery and resource cases. |
| E-10 | P9; E-05c reviewed | Add catalog validation and protocol-specific Overview panels over verified fixed metric queries, with embedded licensed assets. | AC-023/AC-024: HTTP-only, gRPC-only, dual and worker entries; uncatalogued queries; units/aggregation labels; bounded charts; no-data/zero/stale states. |
| E-11 | P9; E-10 reviewed | Complete the existing MVC views, linked investigation, shareable absolute context, keyboard details, visible query/status outcomes and operator runbook. | Full AC-013/AC-015/AC-016/AC-022/AC-025 and remaining frontend AC-023/AC-024. No site login/session subsystem. |
| P10a | P10; E-11 reviewed | Verify actual storage-preserving release/configuration pipelines and record consumed tool/image revisions. | DEP-006 evidence for einblick and other applications. Source support alone does not prove configuration preservation. |
| I-02 | P10; P10a reviewed and O-003 resolved | Prepare the installation bucket/reference and selected retention configuration in the owning repository. | Owning CF checks/previews; complete lifecycle-rule ownership and explicit remote disabling under LIF-002. Preparation and activation remain separate. |
| I-03 | P10; I-02 reviewed and O-001/O-002/O-007 resolved | Prepare identity/ingress, immutable native image, storage capacity/path/profile, one replica with existing rolling updates, resources, listeners, secrets/TLS/trust, probes and lifecycle budgets in the owning repository. | Owning apps/CF previews and release/configuration preservation. Actual CSI permissions, claim lifecycle, graceful close, overlapping startup/lock handoff and readiness remain runtime gates. |
| P10b | P10; I-03 reviewed | Review final-image/platform evidence, supported schema/runtime upgrade and rollback, architectural constraints, active acceptance and recovery runbook. Set pilot observation and stop/rollback criteria. | AC-017/AC-021 and installation preflight evidence; unresolved product gates remain explicit. |
| P10c | P10; P10b reviewed and installation/runtime validation explicitly scoped | Validate installation, rolling replacement and storage recovery, including fresh-volume archive-only reads. | AC-018, non-root writes, read-only root, mounted secrets, probes, bounded close/startup and one active DuckDB writer. Document downtime and permanent-volume-loss consequences. |
| P10d | P10; P10c reviewed and one-client enablement explicitly scoped | Enable one application through its actual runtime-config owner, with explicit logger/metrics/tracer exporters, interval, sampling and TLS/authentication. Observe the agreed pilot window. | AC-020 and final v1 readiness: measured signal rates, retained bytes, peak process memory, disk growth, archive lag/outage reserve, backlog drain and recent/historical query times. Broader rollout requires a later owner decision. |

Each lettered packet has its own review boundary. E-02 covers local DuckDB;
E-07a owns remote feasibility. Include composition/configuration with each
dependency's introduction. Feasibility checks do not replace later
service-boundary acceptance. R2 unavailability blocks P4, not P0–P3. Trace and
metric contracts/fixtures are resolved in P7/P8, with their complete local and
archive evidence gathered then.

## 2. Shared infrastructure constraints

Reuse existing CGO, persistent-storage, R2 bucket/expiration and storage-aware
release tooling. Their interfaces are summarized in
[requirements section 6](requirements.md#6-existing-integration-surfaces).
No shared capability implementation or generic CGO trial is scheduled.
Use existing rolling updates; do not add Recreate or a strategy selector (D-018).

Read the owning repository's instructions, Makefile and CI before selecting its
current validation commands. Previews and resource activation can require
provider credentials and remote state. Account for automatic application of
configuration on merge; preparation alone does not authorize that activation.

## 3. Design checks at implementation gates

These checks retain the unresolved constraints behind the packets. Document the
relevant choices with the implementing patch; later designs do not block E-01.

| Gate | Required design or scenario |
| --- | --- |
| Signal source fixtures at introduction | Inspect log sources in E-01, traces in E-04a and metrics in E-05a. Record actual resource/scope/instance identity and instrumentation versions. Add gzip/empty/unsupported requests, nested typed values/large integers, nanoseconds, correlated/uncorrelated logs, cross-service/midnight spans with events/links, and cumulative/delta/reset/gap/histogram metrics as the relevant signal is implemented. Label manufactured edge cases as synthetic. Later-signal fixtures never block logs. |
| E-01 receipt only | Bound decode/decompression and output, demonstrate actual received content and prevent log-export recursion. State that this local development milestone discards records and supplies no durable acknowledgement. Do not add database interfaces or archive stubs to anticipate later packets. |
| E-02/E-06/E-07a native image | Pin driver, bundled engine and extension versions/licenses as introduced. Verify timestamp binding in E-02, Parquet in E-06 and packaged remote extensions in E-07a, without runtime internet installation. Check required native libraries, image scans, non-root/read-only-root operation and process memory on required platforms. A host CLI run does not establish image behavior. Revalidate the final image in P10. |
| E-03a/E-04a/E-05a response and retry | Commit failure never produces success. Distinguish non-retried partial-success from retryable temporary failure. Define each signal's duplicate/conflict behavior and bounded duplicate horizon when adding its persistence, then exercise retries after archival/eviction in E-09/E-04c/E-05c; avoid an indefinitely growing index. |
| E-03b stable pagination | Choose timestamp tie-breaker, late-arrival behavior and cursor expiry for recent logs. Fixed absolute bounds, keyset pagination and a cursor receipt boundary are proposals to verify. Define and label actual text-search scope consistently. Preserve pagination across local/archive transitions in E-08. |
| E-05b/E-05c metric correctness | Hand-check rates and histogram results for two instances, resets/start times, gaps, temporality, duplicate points and incompatible buckets in E-05b. Aggregate compatible distributions before quantiles; verify lookback across midnight and local/archive boundaries in E-05c. |
| E-06/E-07b/E-08 archive ownership | Define durable batch transitions, immutable source membership, expected content identity, interrupted-transition recovery, per-query source ownership and reader cleanup lifetime as each capability is introduced. Cover upload success before local marking and derivative regeneration whose Parquet bytes may differ. Preserve a usable source through publication/eviction; query-time DISTINCT is insufficient. Extend and repeat for traces/metrics in E-04c/E-05c. |
| Resource bounds at introduction | Bound intake in E-01/E-03a, query work in E-03b, export/workspace in E-06 and upload/remote reads in E-07a/E-07b/E-08. Exercise ingestion/query/export/upload together in E-09 and repeat when adding traces/metrics. Measure database/WAL, spill and completed-file allocation through repeated eviction/checkpoint cycles; deleted rows do not prove reclaimed disk. Reserve space for metadata commits and backlog recovery. |
| E-10/E-11 browser acceptance | Verify URL round-trip/return navigation, keyboard row/span access, bounded large traces, missing correlation and stale/partial/error/cancelled outcomes. Filter Overview traces to active instance/time scope; preserve search focus/caret/selection on refresh. The synthetic prototype leaves these behaviors unproven. |
| I-03 storage/release | Preserve stable PVC identity and optional-profile presence through version updates for einblick and other apps. Choose reclaim/backup arrangements and validate actual non-root volume writes. Protected claims and ReadWriteOnce do not enforce one database writer. |
| I-03 listeners/lifecycle | Align actual listeners, probes, Services and ingress; HTTP 8080/internal gRPC 9090 are proposed installation conventions. Readiness waits for local recovery; R2 outage alone need not fail it. Stop intake/users and close DuckDB within termination grace; bound replacement lock waits. |

## 4. Phase and pilot gates

Review and hand off each packet before selecting the next, including within a
phase. Phase completion uses only its assigned signal/capability evidence;
all-signal and full-v1 scenarios stay open until their later owners finish.

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
| AC-001 | Log durable intake in E-03a and queries in E-03b; trace intake/query in E-04a/E-04b; metric intake/query in E-05a/E-05b. E-01 proves receipt only and does not pass this scenario. |
| AC-002 | E-03a/E-04a/E-05a for signal support/responses and local admission failures; E-09/E-04c/E-05c for archive-outage capacity behavior. |
| AC-003 | Log local typed/precision evidence in E-02/E-03a, Parquet in E-06 and archived queries in E-08; traces in E-04a/E-04c; metrics in E-05a/E-05c. |
| AC-004 | E-03b ordering/pagination, repeated across local/archive transitions in E-08. |
| AC-005 | E-04b local distributed trace; E-04c archived/midnight lookup. |
| AC-006 | E-05b numerical metric semantics; E-05c historical/lookback continuity. |
| AC-007 | E-08 actual log overlap/publication/eviction queries; repeat for traces/metrics in E-04c/E-05c. |
| AC-008 | E-03a/E-04a/E-05a committed-record recovery; E-06/E-07b pending log export/publication recovery, extended to traces/metrics in E-04c/E-05c. |
| AC-009 | E-06 interrupted local log export; E-07b ambiguous remote publication; repeat for traces/metrics in E-04c/E-05c. |
| AC-010 | E-09 log outage, visibility, backpressure and backlog recovery; repeat for traces/metrics in E-04c/E-05c. |
| AC-011 | E-08 fresh-volume log archive discovery and reads; repeat for traces/metrics in E-04c/E-05c. |
| AC-012 | E-09 log policy/retry/expiration scenarios, using E-03a/E-06 policies; extend with trace/metric policies in E-04c/E-05c. |
| AC-013 | Query bounds/cancellation from E-03b onward, log historical work in E-08/E-09, trace/metric coverage in E-04b/E-04c/E-05b/E-05c, browser completion in E-11. |
| AC-014 | Reserved; no v1 work. |
| AC-015 | E-03c/E-04b establish safe rendering/correlation; E-11 completes navigation acceptance. |
| AC-016 | E-03a independent diagnostics, E-03c initial frontend states; E-08/E-09 log backend coverage/failure/recovery, extended in E-04c/E-05c; E-11 completes visible frontend outcomes. |
| AC-017 | Migration/rollback baseline from E-03a; archive/schema evidence from E-06/E-08 and trace/metric additions; full supported upgrade rehearsal in P10 preflight. |
| AC-018 | E-02 local native evidence, E-06 Parquet and E-07a remote-extension packaging; I-03 configuration and release-tooling-preservation evidence; graceful close, lock handoff and readiness under the existing rolling-update path; actual CSI/rollout/final-image validation in P10. Source interfaces alone do not pass this scenario. |
| AC-019 | E-06 derivative cleanup, E-08 safe complete-batch log eviction, E-09 expiration/workspace cycles; repeat for traces/metrics in E-04c/E-05c. |
| AC-020 | P10 one-client pilot and measured report. |
| AC-021 | E-02 consuming build/default review; E-03b/E-08/E-04b/E-04c/E-05b/E-05c DuckDB query review; E-06/E-07b/E-04c/E-05c immutable export review; close applicable review items in P10 preflight. |
| AC-022 | E-03c initial Logs view without site credentials/sessions; E-11 full browser-workflow evidence. |
| AC-023 | E-10 catalog behavior and uncatalogued queries, completed frontend evidence in E-11. |
| AC-024 | E-05b verified profile/numerical fixtures, E-05c historical continuity, E-10 charts and bounded states. |
| AC-025 | E-11 connected investigation, links, selections, keyboard details and explicit trace scope. |
| AC-026 | E-07a actual-R2/dependency/binary/resource evidence, E-07b durable transfer integration, resource checks with later signals and final evidence review in P10 preflight. |

## 6. Completion evidence

No implementation steps have been completed. For each completed step, append a
concise entry with its ID, validated result, actual commands/results, applicable
acceptance portions, patch/base reference, session/PR references or their missing
status, feedback disposition and remaining gates. Keep full task descriptions out
of this section. Removed task rows remain available through their patch/base or
Git history; their IDs remain valid evidence references in the acceptance table.

## 7. Patch handoff and feedback

The agent produces the change and original patch; the human drives refinement
and the PR stage. Capture this evidence within the selected step's handoff rather
than creating another work queue.

### Capture at patch handoff

Retain immutable references to these inputs for each step:

| Input | Required context |
| --- | --- |
| Task and requirements | Step/scope, exact first agent-generated requirements if any, and the requirements revision actually used. |
| Original patch | Complete patch including new/binary files as needed, base commit and content hash or immutable reference. Preserve it before human refinement. |
| Session | Actual session ID(s), roles/runtime and accessible record/export when available. An ID alone does not provide inspectable conversation content. |
| Instructions | Starting repository/dependency revisions and actual bin/skill revision used. |
| Final PR | Reviewed PR with exact base/head or merge revisions, final checks, owner/reviewer corrections and rationale. For docs without a PR, record the accepted document revision. |

Keep references portable. Mark missing or inaccessible inputs explicitly; do not
reconstruct an original patch from the final result or invent session IDs.
Exclude secrets and unrelated source/configuration captures.

At patch handoff, remind the human:

> Retain the requirements revision, original patch/base and actual session ID
> before refinement. Return requirements + original patch + final PR/revisions +
> session ID for feedback review, with an accessible session record if available.

At final-PR or phase close, remind the human to provide that bundle and record
its review or missing-evidence limitations before advancing.

### Review before the next phase

Compare requirements → original patch → final PR using actual session/review
evidence to explain material corrections. Separate new owner direction and
product decisions from patch errors, missing instructions, environment limits
and reusable skill gaps. Missing session content limits causal conclusions.

Propose only the smallest supported change to the existing owning bin skill.
If its rule was already adequate, inspect discovery/compliance before adding
another rule. Keep service-specific policy in this repository.

Review skill changes independently in bin under its current instructions and
validation. Record accepted, deferred, rejected or no-change disposition; adoption
requires a reviewed/versioned change and the next phase's actual consumed revision.
Do not report a proposed change as adopted.

At phase close, record product acceptance and remaining gates, step bundle
references, material corrections, feedback disposition and instruction revision
for the next phase. Missing feedback cannot conceal an unmet product gate.
The owner's continuation request selects the next ready step; feedback review
does not itself authorize skill edits, publishing, deployment or external messages.
