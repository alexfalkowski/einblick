# Shared CGO capability verification and plan update

**Date:** 2026-11-04. **Scope:** Read-only verification of existing bin changes and an einblick planning update. No einblick implementation, sibling edit, image publication or phase execution was started.

## Result and provenance

B-01 is retired from future implementation. [bin PR #660](https://github.com/alexfalkowski/bin/pull/660) delivered the required shared interface in commit `e8ad603613179460aea3096a58cf85e09b9b0992`; that local checkout was clean when inspected. The owner confirms that `duckdb-go` was built and successfully run in an ARM image on an M5 Mac while developing this feature. Treat this as completed ARM capability evidence, rather than scheduling another generic CGO trial. The build/run commands, dependency pins, exact image platform identifier and extension coverage of that run are not available in this bundle; amd64 execution has not been reported.

The local commit message records successful lint/security/routing checks and says no downstream image was built/run. This review inspected that message; it did not observe those earlier checks. The owner's subsequent clarification supplies additional successful image-run evidence and is recorded separately rather than discarded or presented as a run performed in this verification session. The remote PR page could not be fetched; the PR number and merged revision are supported by local Git history.

**Confidence: 95% that the shared interface supplies the capability required by D-005/DEP-001 and duplicate B-01 implementation should be removed.** Basis: the exact source diff, documented supported interface, current lint/routing/negative checks, and the owner's successful native image run. This confidence applies to shared capability coverage, not full service feasibility or unobserved platform/extension results.

## Interface inspected

| Surface | Observed behavior |
| --- | --- |
| [Service Make fragment](https://github.com/alexfalkowski/bin/blob/e8ad603613179460aea3096a58cf85e09b9b0992/build/make/_service.mak) | Exports `static` and passes it to the build helper. `build-docker`, `test-docker` and `release-docker` share that path; build-only validation does not publish. |
| [Build helper](https://github.com/alexfalkowski/bin/blob/e8ad603613179460aea3096a58cf85e09b9b0992/build/docker/build) | `static=0` sets `cgo_enabled=1`, `ldflags=-s -w` and `runtime_image=gcr.io/distroless/cc-debian13`. Omitted/`static=1` keeps CGO disabled, forced static linking and `distroless/static`. Only `0` and `1` are accepted. |
| [Dockerfile](https://github.com/alexfalkowski/bin/blob/e8ad603613179460aea3096a58cf85e09b9b0992/build/docker/go/Dockerfile) | Uses those build arguments with a Trixie builder and copies the resulting executable into the selected runtime. Direct Docker builds retain static defaults. It does not itself copy DuckDB extension assets. |
| [Documentation](https://github.com/alexfalkowski/bin/blob/e8ad603613179460aea3096a58cf85e09b9b0992/README.md) | Documents the opt-in and responsibility for additional native development/runtime libraries. |

The [upstream distroless image inventory](https://github.com/GoogleContainerTools/distroless#what-images-are-available) lists `cc-debian13` for amd64 and arm64. That corroborates image availability, not execution of this application's dependencies on either platform.

## Checks performed in this session

| Check | Result and limit |
| --- | --- |
| `make help` in bin | Passed; confirmed repository command surface. |
| `make scripts-lint` in bin | Passed. |
| `make docker-lint` in bin | Passed. |
| `make -f ../bin/build/make/http.mak -n build-docker platform=amd64` from the sibling web repository | Passed; default service-target routing. |
| Same fragment, `-n build-docker platform=arm64 static=0` and `-n test-docker platform=arm64 static=0` | Passed; native build/test routing. No image build or scan executed. |
| Same fragment, `-n release-docker platform=amd64 static=0` | Passed; production build/scan/push routing inspected only. No publication executed. |
| Same fragment, `build-docker platform=amd64 static=2` | Expected rejection before Docker: `invalid static mode: 2 (expected 0 or 1)`; Make exited 2. This is successful negative validation, not a build failure. |
| `python3 tools/check_handoff.py` in einblick | Passed: 90 requirements, 26 acceptance scenarios, stable IDs preserved, 33 local link targets checked, generated preview matches its source and no external preview assets. Planning integrity only. |

The routing checks used the real web module directory at commit `77a0fb9d2782d294aba7b1ca51f5e21b684ea918`, loading the newly inspected sibling bin fragment explicitly. They did not update web's existing bin pin (`90c1e98a5447d07ddc080193646005c0cdcae7c8`). No sibling files were changed. No image build/run, scanner, actual R2 operation, telemetry capture or browser smoke check was performed in this session.

## Remaining service work and challenge pass

E-02a owns the immutable consuming bin pin, `static=0` configuration and the final einblick release image's driver/engine, extensions, licenses, non-root/read-only-root operation, constrained memory and required-platform coverage. Reuse the owner's successful ARM trial evidence wherever its concrete pins and coverage apply. E-01/O-010 still establish which platforms are required; amd64 validation is needed only if that platform remains required. AC-018 and the full AC-021 remain service acceptance gates; neither is passed in full by the generic image trial.

Challenge checks: the native path changes runtime and linker behavior together, rather than enabling CGO alone; static defaults remain available; build/test/release share the opt-in; amd64/arm64 selection remains supported; DuckDB dependencies are not added to ordinary service images. The executable-only copy leaves final extension packaging with the service. No evidence currently requires another shared-tooling change; reopen it only for a demonstrated missing capability in the selected service stack.

## Handoff and feedback evidence

- **Requirements used:** [immutable revision 0.9](../history/requirements-v0.9.md); SHA-256 `ed3274eb8dcb6de429d9917a4fded749163fc1c446242e0ceff462135ed87d18`. The resulting [revision 0.10](../history/requirements-v0.10.md) is retained in history.
- **Current agent session:** Codex session/thread `01a1a815-0c76-76c2-b7eb-a83135fb7cde`. Its local source record is `~/.codex/sessions/2026/11/04/rollout-2026-11-04T20-41-54-01a1a815-0c76-76c2-b7eb-a83135fb7cde.jsonl`; access requires the source machine. A portable export has not been bundled; the ID alone does not provide conversation access.
- **Instructions used:** einblick AGENTS.md, bin AGENTS.md and `skills/project-workflow/SKILL.md` plus its Make-fragment reference at the inspected bin revision. No skill change was made.
- **External bin feedback inputs:** Final merged revision/PR identity is known from local history; original feature requirements, original agent patch/base, implementation session IDs and accessible transcripts were not supplied. No requirements-to-original-patch-to-PR comparison or skill-feedback completion is claimed. These missing inputs do not block retiring duplicate implementation.
- **Future packets:** Follow [the feedback process](../phase-feedback.md) for requirements, original patches, final PRs and session records. At P0 review, record unavailable external bin evidence rather than inventing history.
