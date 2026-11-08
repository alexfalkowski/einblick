# Infraops persistent-storage delivery and plan update

**Date:** 2026-11-04. **Scope:** Read-only source inspection and an einblick documentation update. No sibling repository was edited; no remaining implementation, release adoption or deployment was started.

## Delivery and evidence boundary

The owner reports that I-01a landed. The clean local infraops checkout contains commit [`342ca738ac0d618341389bfc9644c0e3b4831b66`](https://github.com/alexfalkowski/infraops/commit/342ca738ac0d618341389bfc9644c0e3b4831b66), `feat(apps): add protected persistent storage`, based on `10ca118ba2374d3fb28053ff28ff1efcd08ba6ba`. This is the inspected implementation revision, not an independently verified merge SHA. The local checkout is on a feature branch and cached `origin/master` still points to the base. A read-only `gh pr view` lookup failed to connect to api.github.com; no remote PR number, merge metadata or CI result was retrieved. This access limit does not contradict the owner's delivery report or require repeating the implementation.

**Disposition:** Retire I-01a from future implementation. Keep I-01 partial until I-01b supplies Recreate. I-02 archive resources, release-tooling adoption, I-03 installation configuration and actual runtime acceptance remain future work.

**Confidence: 95% in the plan/status update**, supported by the owner's delivery report, exact commit diff, schema/generated code, resource wiring, existing mock scenarios and README activation contract. This is not a confidence claim for remote merge metadata, tests not rerun here, CSI behavior or a deployed single writer.

## Delivered interface

| Surface | Inspected contract |
| --- | --- |
| [Schema](https://github.com/alexfalkowski/infraops/blob/342ca738ac0d618341389bfc9644c0e3b4831b66/api/infraops/v2/service.proto) | Optional `Application.storage` with required `capacity` and absolute, clean, non-root `path`; optional `profile`. Generated `service.pb.go` is included. |
| [Storage resource](https://github.com/alexfalkowski/infraops/blob/342ca738ac0d618341389bfc9644c0e3b4831b66/internal/app/storage.go) | Creates `<app>-data` in the app namespace, with `ReadWriteOnce`, `Filesystem`, explicit requested capacity and `pulumi.Protect(true)`. Omitted profile leaves StorageClass assignment to the cluster; empty requests no class; named selects that class. It does not create a StorageClass or set the backing PV reclaim policy. |
| [Deployment](https://github.com/alexfalkowski/infraops/blob/342ca738ac0d618341389bfc9644c0e3b4831b66/internal/app/deployment.go), [container](https://github.com/alexfalkowski/infraops/blob/342ca738ac0d618341389bfc9644c0e3b4831b66/internal/app/container.go) | Wires the stable claim and whole-volume writable mount without subPath. Existing UID/GID 10001, fsGroup 2000, read-only root and other security settings remain. Omitted storage keeps config/secret-only volumes. Rolling updates and the disruption budget remain unchanged. |
| [Lifecycle/activation documentation](https://github.com/alexfalkowski/infraops/blob/342ca738ac0d618341389bfc9644c0e3b4831b66/README.md#-persistent-application-storage) | Claim removal/replacement requires deliberate unprotection after backup/migration. Rename/namespace changes do not migrate data. CSI permissions/expansion/recovery and backing-volume reclaim behavior need installation evidence. Pulumi protection does not prevent direct Kubernetes/namespace deletion. |

I-03 chooses installation capacity/profile and a dedicated mount, with the proposed database/recovery/export/workspace layout beneath `/data`. I-01a neither selects production sizing nor creates live resources merely by landing code. `ReadWriteOnce` is not exclusive-writer enforcement; I-01b remains necessary for ordinary update ordering.

## Release-tooling prerequisite

The new infraops README explicitly requires storage-aware release tooling before storage activation. `internal/app/version.Update` reads and rewrites the complete apps configuration, so a release of another application also needs to preserve storage fields and optional-profile presence.

The inspected clean docker checkout at `ea8e62aa27f3f0f6207b93ddbf3b9e15e4f297a6` still installs [`cmd/bump` 2.549.0](https://github.com/alexfalkowski/docker/blob/ea8e62aa27f3f0f6207b93ddbf3b9e15e4f297a6/release/Dockerfile). The inspected web, abgleich, bezeichner and standort pipeline sources reference `alexfalkowski/release:8.45`. These are source observations, not an inspection of deployed release binaries or a complete inventory of all possible writers.

Before I-03 adds `storage`, separately select the docker release-image update to a published storage-aware bump version and the adoption changes for every pipeline that rewrites apps configuration. Record actual tool/image revisions and show that releases of the storage-enabled application and another application both retain all storage settings. No new version number, image publication or consumer update is invented or executed by this plan update.

## Checks and remaining acceptance

In this documentation pass: inspected the full source diff, storage/configuration/resource wiring, storage mock scenarios and fixture, rollout settings, version-rewrite path, release-image pin, representative consumer pins, repository instructions/Make/CI surfaces and clean working-tree status. `make help` in infraops passed. `gh pr view` failed because api.github.com was unreachable; this is a network/access limitation, not evidence about implementation behavior.

The implementation commit reports successful `make dep`, focused app/version specs with race detection, scoped lint, API generation/lint/breaking checks, scoped coverage, vulnerability/repository scans and diff checks. It reports two reviewer passes. Those are commit-reported results; this pass did not rerun tests, inspect reviewers' sessions, verify CI, or reproduce scanner results. The inspected mock scenarios cover omission, profile round-trip semantics, claim identity/protection, mounts/security/default rollout, invalid paths and resource errors. Their presence is not live CSI evidence.

`python3 tools/check_handoff.py` passed: 90 requirements, 26 acceptance scenarios, stable IDs preserved, 35 local link targets checked, generated preview matches its source and no external preview assets. This validates planning-bundle integrity. No prototype behavior changed, so browser smoke was not rerun. No Pulumi preview/update, CSI write/expansion/recovery exercise, image build or R2 operation was performed.

Challenge pass: the diff adds storage only, leaving Recreate unimplemented; protected claims are distinct from backup/reclaim policy; source capability is distinct from live volume readiness; old release writers remain an activation dependency; and I-01a delivery is distinct from parent I-01, AC-018 or phase-feedback completion. No repeated PVC/mount implementation is needed.

## Handoff and feedback

- **Requirements input:** [immutable revision 0.10](../history/requirements-v0.10.md), SHA-256 `1b89cfe07e4fa989debc0570ae02a96d1116c07d60543a1f1f1dfeabf5086dee`. The resulting [revision 0.11](../history/requirements-v0.11.md) is retained in history.
- **Current documentation session:** Codex session/thread `01a1a815-0c76-76c2-b7eb-a83135fb7cde`; local source record `~/.codex/sessions/2026/11/04/rollout-2026-11-04T20-41-54-01a1a815-0c76-76c2-b7eb-a83135fb7cde.jsonl`. This requires source-machine access; no portable export is bundled. An ID alone does not provide conversation access.
- **Instructions used:** einblick AGENTS.md, infraops/bin guidance and its `project-workflow`/`change-validation` skills/references. Infraops consumes bin revision `e8ad603613179460aea3096a58cf85e09b9b0992`. No skill changes were made.
- **Missing implementation feedback inputs:** The I-01a prompt exists in this documentation session, but the exact input used by the implementing agent, original implementation patch/base, implementation-session IDs/export and final PR/base-head/merge metadata have not been supplied. Do not reconstruct the original patch from the final commit or claim a requirements-to-patch-to-PR/session review occurred.
- **Future packets:** Follow [feedback review](../phase-feedback.md) for requirements, original patches, final PRs and session records. For landed I-01a, record unavailable implementation feedback inputs. No phase-feedback completion or next-packet authorization is inferred.
