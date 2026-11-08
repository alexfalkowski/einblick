# R2 lifecycle and release-tooling dependency refresh

**Date:** 2026-11-04. **Scope:** Source verification and planning-document refresh following the owner's reports that docker/infraops changes landed and rollout is in progress, then the request to verify and remove stale requirements. No sibling source, active infrastructure configuration or einblick implementation was changed.

## Inspected delivery evidence

PR numbers below come from local commit metadata and the owner's delivery report. Remote CI and live rollout results were not retrieved.

| Dependency | Immutable source/reference | Observed result |
| --- | --- | --- |
| Infraops storage | [PR #3763](https://github.com/alexfalkowski/infraops/pull/3763), `a2c6f88f081e761fbef71aef05cf3215b73e90d6` | Delivered protected-PVC/mount capability; replaces the earlier feature-commit reference as the delivery revision. No Recreate addition. |
| Infraops R2 expiration | [PR #3764](https://github.com/alexfalkowski/infraops/pull/3764), `ded49c5c48800ec121b400a9f3490ae795c450a6`; local tag `v2.617.0` resolves to this commit | Optional `Bucket.expiration` is present in schema/generated code and converted into an R2 lifecycle resource. |
| Docker release tooling | [PR #1818](https://github.com/alexfalkowski/docker/pull/1818), `cd711259ac9b72634adb91a758e1e9a11d2d0dd5` | `release/Dockerfile` installs bump `2.617.0`; `release/Makefile` declares image version `8.48`. |
| abgleich pipeline | [`8ac383b08bcf49b8e1d8c0cea6315f6257209116`](https://github.com/alexfalkowski/abgleich/blob/8ac383b08bcf49b8e1d8c0cea6315f6257209116/.circleci/config.yml) | Deployment job uses the release executor pinned to `alexfalkowski/release:8.48`. |
| bezeichner pipeline | [`c043735641b5e35fedd0d3bedb650b12d8648263`](https://github.com/alexfalkowski/bezeichner/blob/c043735641b5e35fedd0d3bedb650b12d8648263/.circleci/config.yml) | Same pin and deploy path. |
| standort pipeline | [`9b57e0b847d8208f58589923763ec6fd7fb1ba5f`](https://github.com/alexfalkowski/standort/blob/9b57e0b847d8208f58589923763ec6fd7fb1ba5f/.circleci/config.yml) | Same pin and deploy path. |
| web pipeline | [`9dc319b9ea61a887801e62d5ea34f573da0fd337`](https://github.com/alexfalkowski/web/blob/9dc319b9ea61a887801e62d5ea34f573da0fd337/.circleci/config.yml) | Same pin and deploy path. |

Local inspection baselines were infraops `9e7da83c6c47a70d0d58d8d6d80ea679873f1448` and docker `ee205763aafde745098e7524d6ae2704b623736e`; both working trees were clean. The four application revisions above were the inspected HEADs. A search for `.cd` markers outside Git, vendored source and bin checkouts found these four consumers. Docker's `release/deploy` gates its configuration-writing path on that marker, and their deployment jobs use that script. This establishes source coverage for the inspected consumers, not successful pipeline execution.

The `v2.617.0` source includes `Application.storage` and optional `Storage.profile`. `cmd/bump` calls the application version updater, which loads the complete protobuf configuration, changes the selected version, and writes the complete configuration. This removes the old-tool implementation dependency; actual image contents and storage preservation through real releases remain AC-018 evidence. No local image inspection, bump execution or release was performed.

## Delivered R2 interface and remaining work

The [owning infraops contract](https://github.com/alexfalkowski/infraops/blob/ded49c5c48800ec121b400a9f3490ae795c450a6/README.md#-r2-object-expiration), schema and resource code establish:

- `expiration` is optional Go duration text. `168h` and `24h` are examples; values must resolve to positive whole seconds within `time.Duration`. `7d`, zero, negative and fractional-second values are rejected before resource registration.
- An omitted value registers no lifecycle resource. A configured value applies to all objects by object age and retains seven-day incomplete multipart cleanup. The lifecycle resource references the created bucket's name output; the existing bucket and optional custom-domain paths remain in place.
- The resource manages the complete lifecycle rule set rather than merging independently managed rules. Infraops documents that its pinned provider leaves remote rules active when the configured resource is removed; operators must follow its explicit disable/remove procedure and inspect the remote result. This provider limitation was verified as the owning repository's documented contract; fetching the linked upstream implementation failed with a web cache miss, so no independent upstream-code or live deletion verification is claimed.
- Cloudflare's [object lifecycle documentation](https://developers.cloudflare.com/r2/buckets/object-lifecycles/) was inspected and confirms asynchronous deletion, effects on existing objects and default seven-day multipart cleanup. It does not establish observed behavior for this installation.

Retire I-02's lifecycle-capability implementation and the delivered release-image/consumer pin changes. I-02 remains partial: the inspected `area/cf/cf.hjson` declares no buckets, and private test-bucket access, installation ownership, policy selection and activation remain open. O-003 is not resolved by adding optional object-age expiration. I-01b Recreate is still missing from the inspected deployment code. The owner's rollout report is recorded as **in progress**, not complete. Confirm actual image/tool execution and storage-preserving releases before storage activation.

## Checks, challenge pass and scope limits

The R2 implementation commit reports generation/API checks, 32 scoped CF tests, scoped coverage/lint, related area/formatter tests and security checks. Those are commit-reported results; this documentation task did not rerun them or inspect final CI. No Go source changed here, and no backend, image, Pulumi, CSI or R2 runtime validation was performed. Prototype behavior was unchanged, so browser smoke was not rerun.

`python3 tools/check_handoff.py` passed: 90 requirements, 26 acceptance scenarios, stable IDs preserved, no undefined/unmapped IDs, 38 local link targets checked, and the generated self-contained preview matches its source. This checks planning-bundle integrity, not operational acceptance.

Challenge pass: code delivery is distinct from image/pipeline execution; consumer pins are distinct from completed rollout; lifecycle capability is distinct from bucket provisioning and policy agreement; optional-field omission is distinct from disabling previously applied remote rules; and storage remains distinct from one-writer rollout. Earlier dated ecosystem observations and immutable evidence/history remain historical observations, not current live-state claims.

**Confidence: 95% in this scoped requirements/status refresh**, supported by exact source/tag inspection, supported release-consumer paths, the owner-reported delivery/rollout status and planning-bundle checks. Actual rollout, durability, R2 operation/deletion and final service feasibility remain unverified.

## Original documentation handoff and feedback

- Requirements input: [immutable revision 0.11](../history/requirements-v0.11.md). The resulting [revision 0.12](../history/requirements-v0.12.md) is retained in history.
- Guidance used: einblick AGENTS.md; inspected sibling guidance; `project-workflow`, `doc-standards`, `change-safety` and `change-validation` from bin revision `e8ad603613179460aea3096a58cf85e09b9b0992`. No skill changes were made.
- Current documentation session ID and accessible session export were not exposed in the supplied task context and have not been captured. Do not substitute a prior session's ID.
- External implementation feedback is incomplete: final source references are known, but original implementation patches/bases, exact requirements revisions, implementing session IDs/accessible records and final CI/rollout evidence were not supplied or inspected. Do not reconstruct original patches from final commits or claim a requirements-to-patch-to-PR/session review occurred.
- Future packet reminder: retain requirements + original patch/base + the actual session ID and accessible session record/export before refinement, and return final PR/revisions for [feedback review](../phase-feedback.md). Supply missing external implementation evidence when available. No phase-feedback completion or next-packet authorization is inferred.
