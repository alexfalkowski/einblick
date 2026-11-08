# Rollout scope correction

**Date:** 2026-11-04. **Scope:** Requirements and planning only. The owner rejected a global Recreate default, then explicitly requested removal of the proposed Recreate work so it would not be built.

## Decision and effect

D-018 records the agreed direction: reuse the existing rolling-update behavior. I-01b is **superseded without implementation**, not a delivered capability or an outstanding dependency. Its ID is retained for traceability; its task rows, dependency-graph edges, I-03 prerequisites and P4 scheduling are removed. AGENTS.md explicitly prevents future agents from implementing the superseded capability, strategy selector or shared-default change for this project.

DEP-005, DEP-010 and AC-018 retain the required behavior: graceful termination closes DuckDB after stopping database users; only one process holds the database for writing; overlapping replacement startup handles temporary lock unavailability within bounded startup; and intake readiness waits for database access and recovery. Validate this through the existing deployment path and actual persistent volume during integration. This is future service/runtime evidence, not a claim that the existing rollout has already passed.

The earlier assumption that an infrastructure strategy change was mandatory was too strong. Kubernetes documents [graceful pod termination](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#termination-of-pods) and [overlap during rolling updates](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment); DuckDB documents [single-process read/write access and file locks](https://duckdb.org/docs/2.0/connect/concurrency). These sources were inspected during the discussion. They explain the shutdown/startup validation requirement without proving a need for new infrastructure functionality. The selected driver and actual volume behavior still need service-specific verification.

There are no further planned shared-code prerequisites to build. Delivered CGO, persistent-storage, optional R2 expiration and release-tooling capabilities remain available. External work still includes test-R2 access/credentials, rollout confirmation, bucket/policy activation, installation storage/TLS/client configuration and actual operational validation. P0's native packaging and S3-client feasibility checks may reveal evidence requiring a separately scoped follow-up; this decision does not preauthorize one.

## Validation and history

Preserved [requirements revision 0.12](../history/requirements-v0.12.md) exactly. Earlier history and evidence, including the [dependency refresh](r2-release-verification.md), remain immutable point-in-time records and may mention the superseded proposal. Current requirements, plan, README, feedback process and agent guidance now carry the owner's correction.

`python3 tools/check_handoff.py` passed: 90 requirements, 26 acceptance scenarios, stable IDs preserved, no undefined/unmapped IDs, 40 local link targets checked, and the generated self-contained preview matches its source. A targeted scan confirmed no scheduled I-01b task rows, dependency-graph edges or pending-capability wording remain in active guidance. Prototype behavior did not change; browser smoke and backend/infrastructure tests are not applicable to this documentation-only update. No sibling repository, service implementation or live infrastructure was changed.

Challenge pass: removing a strategy prescription does not remove the single-writer/durability invariant; graceful close does not establish replacement ordering; two overlapping processes do not imply two permitted database writers; and source/documentation checks do not establish actual rollout behavior.

**Confidence: 95% in this scoped documentation change**, supported by the explicit owner instruction, the coordinated requirements/plan/guidance changes and planning-bundle checks. Runtime rollout behavior remains unverified.

## Original patch and feedback

- Input: requirements revision 0.12, retained above. This update produced revision 0.13.
- Guidance used: einblick AGENTS.md and the previously inspected bin `doc-standards`, `change-safety` and `change-validation` guidance at revision `e8ad603613179460aea3096a58cf85e09b9b0992`; no skill edits were made.
- Actual session ID and accessible transcript/export have not been exposed in the supplied task context or captured. Keep this limitation visible; do not reuse another session's ID.
- For future packets, retain requirements + original patch/base + actual session ID and accessible session record/export before human refinement. Return final PR/revisions or the accepted documentation revision for feedback inspection. Missing session capture remains open; this update does not complete phase feedback or start another packet.
