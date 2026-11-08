# Planning and prototype handoff

A small telemetry service for our services built on go-service: OTLP/gRPC ingestion, DuckDB for recent data and queries, Parquet archives in Cloudflare R2, and an embedded service dashboard.

This folder contains the requirements, research, and an interactive UX concept. The repository now has a Go service scaffold; the telemetry product described here and its deployment remain planned. The requirements retain the original working-name context.

## 🧭 Start here

Read [planning guidance](planning-guidance.md), then [the current requirements](requirements.md). The requirements own the decisions, stable requirement IDs, acceptance scenarios, delivery phases, and open questions. Earlier revisions are retained under [docs/history](history/).

The [design review and staged implementation plan](review-and-plan.md) documents smaller P0–P4 review units, repository responsibilities, dependencies and acceptance coverage. Shared CGO (B-01), infraops persistent storage (I-01a), and I-02's optional R2 expiration capability are delivered. Release image 8.48 installs `bump` 2.617.0, and all four deployment pipelines pin that image; the owner reports rollout in progress. These source changes need no repeat implementation. The [dependency refresh](evidence/r2-release-verification.md) records exact revisions and remaining evidence; earlier [CGO](evidence/bin-cgo-verification.md) and [storage](evidence/infraops-storage-verification.md) records remain available.

The owner [removed the proposed Recreate work](evidence/rollout-scope-update.md); I-01b is superseded without implementation. Use the existing rolling-update behavior and validate graceful DuckDB shutdown, one active writer and startup/recovery. Bucket/reference configuration, retention policy, rollout confirmation and storage-preserving release checks remain open before installation. The requirements remain the product contract. **Current einblick work is planning only; its implementation phases remain unstarted.** This handoff does not start implementation.

The [remaining planning gaps](review-and-plan.md#11-remaining-planning-gaps) track phase-local policies and evidence. [OpenTelemetry contracts are inherited by reference](requirements.md#11-inherit-standards-and-derive-routine-details); agents derive routine implementation details from supported repository patterns and document them with the selected patch. Later-phase detail does not block unrelated earlier work.

Future phases run one by one. The agent produces a patch; the human drives it to the PR stage. The [phase feedback process](phase-feedback.md) retains **requirements + original patch + final PR + session ID** for inspection of what drove the changes and for separate reviewed improvements to `bin` skills. [Planning guidance](planning-guidance.md#phase-handoff-and-reminders) requires reminders at patch handoff and final-PR/phase close. An accessible session record/export is retained when available; no scheduled notification is configured.

The planning bundle now lives in the einblick service repository. Run the commands below from the repository root. No dependency installation or sibling repository is needed to review the static concept.

## 🎨 Review and refine the prototype

Open [prototype/index.html](../prototype/index.html) in a browser. It runs locally without a server or network assets and uses synthetic telemetry.

- [Overview](../prototype/screenshots/overview.png): protocol-specific charts and runtime context.
- [Logs](../prototype/screenshots/logs.png): search, severity filtering, and log details.
- [Trace details](../prototype/screenshots/trace-detail.png): span waterfall, attributes, and related logs.

The editable source is [prototype/template.html](../prototype/template.html). After editing it, rebuild the self-contained preview from the repository root:

```sh
python3 prototype/build.py
```

The builder embeds the pinned uPlot JavaScript, CSS, version, and MIT license from [prototype/vendor](../prototype/vendor/). Edit the template, rather than the generated HTML. The mockup demonstrates interaction; it is not the final MVC implementation, and not every requirement is demonstrated.

The proposed service catalog is illustrated in [examples/services.yaml](../examples/services.yaml). It is a design example, not a complete executable service configuration or a verified inventory of deployed protocols.

## ✅ Check changes

With Python 3, check links in the root README, AGENTS.md, and all active Markdown documents under `docs/`, plus requirement references, stable IDs, the generated preview, and embedded assets:

```sh
python3 tools/check_handoff.py
```

Links into declared, uninitialized Git submodules are skipped and listed in the result's `uninitialized_submodule_links` field. After submodule initialization, those links are checked normally. Historical snapshots under `docs/history/` retain their original links and are excluded from link checks; their stable requirement IDs are still checked.

The existing browser smoke check needs a modern Node.js with built-in `fetch` and `WebSocket`, plus Chrome/Chromium. It was exercised with Node 26 and Google Chrome on Linux. Run it from the repository root:

```sh
node prototype/smoke.mjs
```

Set `CHROME_BIN` if Chrome is not named `google-chrome` on your PATH, for example on macOS:

```sh
CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" node prototype/smoke.mjs
```

In containers that require Chrome's sandbox override, set `CHROME_NO_SANDBOX=1` for this local synthetic prototype check. Browser profiles use a temporary directory and are removed afterward. The check refreshes [screenshots](../prototype/screenshots/) and [validation results](../prototype/validation/).

These checks cover the planning bundle and synthetic UX. DuckDB packaging, actual go-service payloads, resource sizing, and R2 compatibility have not been demonstrated. Use the repository README and `make help` for the separate Go service build/test workflow.

## 🧩 Continue refinement

Start with the [open-decision register](requirements.md#15-open-decision-register). Useful next work is to refine the service views, confirm the actual go-service metric profile, and tighten the initial query/storage contracts. Keep decisions and proposed defaults distinct.

The shared CGO capability and an ARM `duckdb-go` image trial are complete. Einblick's final native/extension packaging and the lean S3 client still need their service feasibility evidence. Site authentication is explicitly deferred. The requirements contain the full durability boundary, including the risk to unarchived data after complete persistent-volume loss.

To continue with another agent, a suitable starting request is:

```text
Read AGENTS.md, docs/planning-guidance.md, and docs/requirements.md in this repository.
Continue preparing the einblick planning handoff with me.
Read docs/review-and-plan.md. Do not begin implementation or execute its units.
Preserve the agreed scope and requirement IDs. Start by identifying the
open decisions most relevant to my next request. Keep the documents and
prototype consistent as we refine them.
```
