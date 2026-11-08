# Planning guidance

## Purpose and current state

This is the planning and UX handoff for **einblick**, a proposed telemetry service for our own services built on go-service. It is not a general-purpose observability product. The requirements retain their original working-name context; the service repository and executable are now named einblick.

The current work is requirements, design refinement, research, and a static interactive prototype. The repository has a Go service scaffold, `go.mod`, and an initial API contract; the telemetry backend and its deployment remain planned. Follow the current user request when deciding whether to refine the design or begin implementation; this folder alone does not authorize deployment, publishing, or changes to sibling repositories.

## Read first and keep one source of truth

1. Read [planning handoff](planning.md) for artifact ownership and usable commands.
2. Read [docs/requirements.md](requirements.md), particularly the decision register, requirements relevant to the request, delivery phases, and open decisions.
3. For staged work, read [docs/review-and-plan.md](review-and-plan.md) and [docs/phase-feedback.md](phase-feedback.md).
4. Inspect [prototype/template.html](../prototype/template.html) and [prototype/index.html](../prototype/index.html) for UX work.

The current requirements own the product contract. The README is orientation; this file guides agent work; the prototype is illustrative. Files in `docs/history/` are immutable historical snapshots, not active requirements. Historical UI-authentication requirements are superseded and must not be restored accidentally.

Preserve requirement, decision, acceptance, and open-question IDs. Mark superseded items rather than reusing IDs. Update affected acceptance scenarios, delivery phases, examples, and the revision history when a decision changes. Distinguish user-agreed direction, proposed defaults, and evidence still needed. Do not label a proposal as agreed without support from the conversation or requirements.

Inherit applicable OTel contracts and derive routine details from supported repository conventions under [requirements section 1.1](requirements.md#11-inherit-standards-and-derive-routine-details). Do not require the owner to restate standard fields/semantics or preapprove every schema, query or config detail. Document the chosen implementation with its scoped patch and raise material departures or missing evidence. Only relevant unresolved choices block a packet; no implementation starts during planning.

## Phase handoff and reminders

- Work one phase and one selected packet at a time. Planning requests do not start execution.
- When later authorized to implement a packet, produce the scoped change and original patch, then hand it to the human. The human drives refinement and the PR stage; patch production alone does not authorize push, PR creation, merge or a later packet.
- Preserve the first requirements version, the requirements revision used, the original complete patch and base revision, actual agent session ID(s), and the skills/bin revision used. Do not overwrite the original patch with the human-refined result.
- **At every patch handoff, remind the human to retain requirements + original patch + session ID and to return the final PR/revisions for inspection.** Link the evidence record and identify missing capture items. Include an accessible session record/export reference when available; an ID alone is not evidence that another agent can inspect the conversation.
- **When a final PR is supplied or a phase is closing, remind the human to feed requirements + original patch + PR + session ID into the feedback review before advancing.** Follow [the phase feedback process](phase-feedback.md); record missing-evidence limitations rather than inventing history.
- Keep resulting bin skill improvements in separate reviewed changes. These are workflow reminders, not scheduled notifications or authority to send external messages. Do not start skill changes or the next phase automatically.

## Preserve the agreed direction

- One instance initially; receive logs, metrics, and traces over standard internal OTLP/gRPC using go-service facilities.
- Keep the existing rolling-update behavior. D-018 supersedes I-01b: do not implement Recreate, a rollout-strategy selector or a changed shared default for this project. Validate graceful DuckDB shutdown, one active database writer, bounded startup/lock handling and readiness after recovery using the existing deployment path. Earlier evidence and history may retain the superseded proposal.
- DuckDB is the selected database candidate. Validate its pinned Go driver, engine, extensions, required platforms, and native packaging. Allow this service to opt into CGO while retaining other services' default.
- Use a persistent local DuckDB database/WAL and durable export jobs. Acknowledge after local commit; archive asynchronously as immutable Parquet batches to private Cloudflare R2.
- Partition archives by signal and UTC event day. Keep application identity in columns initially; add physical application partitioning or compaction only when evidence justifies it.
- Bound whole-process memory, query work, disk/workspace, and transfer buffers. Accept slower queries instead of requiring a large in-memory recent window. Approximately 15 minutes of recent data is not a RAM-residency promise.
- Ordinary restart reopens the persistent volume and resumes jobs. Complete volume loss can lose unarchived data; R2 discovery is rebuildable. Do not replicate a live `.duckdb` file by periodically uploading it.
- Use DuckDB for filtering and aggregation. Do not introduce our own general query engine, a second storage engine, or an arbitrary browser SQL console.
- Provide ready-made Overview, Logs, and Traces views through embedded go-service MVC assets. Follow the sibling web service's lightweight MVC/htmx/Pico pattern; uPlot is the demonstrated plotting candidate. No heavy frontend framework or required Grafana deployment.
- A small service catalog declares the service ID and incoming server protocols (`http`, `grpc`, or both through a list). The catalog chooses panels; it is not an ingestion allowlist. The standard metric profile is specific to our supported go-service instrumentation.
- Site authentication is deferred to a future shared go-service solution. Do not add login, mounted UI credentials, or browser sessions to v1. R2 credentials and internal ingestion TLS/authentication are separate concerns.
- Use a lean existing Go S3 library, excluding both AWS Go SDKs and runtime wrappers around them. Do not implement our own S3 signer/client. `go-micro-s3/client` is a candidate requiring R2, memory, dependency, license, and linked-binary validation; it is not a proven production choice.
- Keep retention configurable; seven days is an acceptable normal starting direction, with a shorter test value. Start rollout with one application after feasibility and implementation evidence.

## Evidence and scope

The requirements record source observations from 2026-11-02/03, not live infrastructure state. Recheck instrumentation, deployed configuration, library APIs/maintenance, and packaging when work depends on them. Use primary sources for technical research and record what was actually inspected or measured.

The prototype uses synthetic versions, traffic, operations, traces, and dependencies. Its successful browser checks demonstrate the concept's behavior, not OTLP correctness, database durability, resource budgets, R2 compatibility, or production readiness. Native OTel metric names/units/attributes need verification; Prometheus names in the existing Grafana dashboard are only a semantic reference.

Relevant sibling repositories are `go-service`, `web`, `docker`, `infraops`, `abgleich`, `bezeichner`, and `standort` when available. Follow each repository's own `AGENTS.md`, accepted-design guidance, skills, and command conventions before working there. Do not copy credentials, `.env` files, browser profiles, or unrelated source trees into this handoff.

Keep refinement incremental. Work from the open-decision register instead of reopening settled tradeoffs without new evidence. Resolve routine implementation details within the authorized task; present material alternatives with their concrete consequences. Follow the active session's delegation rules; this handoff does not itself grant sub-agent or external-message authorization.

## Prototype and validation

- Treat the prototype as a disposable visual reference. Build final MVC views from the requirements and supported repository patterns; use [R-07](review-and-plan.md#r-07-keep-prototype-success-separate-from-frontend-acceptance) for known interaction limitations and acceptance follow-ups.
- Edit `prototype/template.html`; run `python3 prototype/build.py` to regenerate `prototype/index.html` and the syntax-check extract under `prototype/validation/`.
- Preserve the pinned uPlot version and license under `prototype/vendor/`. Keep the preview self-contained and move-safe; no developer-specific absolute paths, CDN assets, or network service is needed to view it.
- Run `python3 tools/check_handoff.py` for bundle integrity. If changing UX behavior or its smoke harness, also run `node prototype/smoke.mjs` with the Chrome settings documented in docs/planning.md. Do not imply those checks validate a backend.
- Keep links relative so the planning bundle remains usable in this repository or another checkout. Keep current commands aligned with the actual files.
- Report what changed, actual checks, and remaining uncertainty. Keep conclusions proportional to evidence; do not claim implementation or production readiness from this planning bundle.
