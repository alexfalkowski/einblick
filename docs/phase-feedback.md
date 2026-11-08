# Sequential phases and skill feedback

**Status:** Agreed delivery-process direction, documented on 2026-11-03; dependency updates on 2026-11-04. Einblick implementation phases and skill changes remain unstarted. CGO (B-01), storage (I-01a), I-02's lifecycle capability and release-image/consumer source changes are delivered dependencies; rollout is owner-reported in progress. Their delivery and missing feedback inputs are recorded separately. I-01b is superseded without implementation under D-018; I-02 retains resource/policy activation work.  
**Product contract:** [requirements.md](requirements.md).  
**Work breakdown:** [review-and-plan.md](review-and-plan.md).

The owner will work through phases one by one and use each phase to improve the shared agent skills in `bin`. The agent writes the selected change and generates a patch; the human then drives it through refinement and the PR stage. Inspect **requirements + original agent patch + final PR + session ID** together to understand the path to the accepted result. Preserve the first requirements version as well as the requirements revision actually supplied to the implementing agent when they differ. Preparing this plan does not start a phase or a skill-maintenance task.

## 1. One active phase and review packet

Execute P0, then P1, P2, P3 and P4. Within the active phase, select one review packet at a time, including changes in different repositories. Independent `einblick`, `bin` and `infraops` changes keep separate PRs and validation; they are scheduled serially. A dependency becoming available does not activate its consumer.

| Phase | Planned packet order | Phase closing record |
| --- | --- | --- |
| P0 | E-01 → I-02 test-resource/reference portion if needed → E-02. Consume existing CGO support and record delivered storage/lifecycle interfaces; their implementation is removed from future execution. E-01 records existing-rollout lifecycle and recovery inputs; no strategy change is scheduled. | Feasibility/contract evidence, final PR references, first-draft comparisons, and disposition of skill feedback. Retain delivered dependency references and missing-evidence dispositions. |
| P1 | E-03 → E-04 → E-05, with their smaller review packets. | Recent-data and signal acceptance evidence plus feedback disposition. |
| P2 | E-06 → E-07 → E-08 → E-09. | Archival, overlap, recovery, retention and resource evidence plus feedback disposition. |
| P3 | E-10 → E-11. | Completed service UX evidence plus feedback disposition. |
| P4 | Confirm delivered release-tooling rollout and storage-preserving execution → I-02 final installation-resource/retention portion → I-03 → preflight/recovery review → explicitly scoped installation validation → one-client pilot. Reuse delivered storage, lifecycle and release-image/consumer source changes. | Deployment/pilot evidence including graceful close, single-writer lock handoff and recovery under existing rolling updates, actual tool/image revisions and release/configuration-preservation evidence, final feedback disposition and the owner's separate broader-rollout decision, if any. |

At a phase boundary, review both the product result and the feedback record. Start the next phase only when the owner selects it after that review. Feedback may result in an accepted skill change, a documented decision that no change is needed, or an explicitly deferred candidate. A deferred candidate records why it can wait; it must not conceal an unmet product acceptance gate or a correction needed for the next phase.

B-01 was delivered independently in bin PR #660 before einblick execution, with an owner-confirmed successful ARM duckdb-go image run on an M5 Mac. The [verification record](evidence/bin-cgo-verification.md) preserves its commit and inspected scope; the original bin requirements, original agent patch and implementation-session content were not supplied, so no requirements-to-PR comparison or skill-feedback completion is claimed. Retain those inputs if available and feed requirements + original patch + final PR/revisions + session ID into feedback review before advancing P0. This does not schedule another B-01 implementation or generic native image trial; final einblick packaging remains E-02 work.

I-01a is delivered. The [storage record](evidence/infraops-storage-verification.md) preserves the original implementation inspection and missing-feedback disposition; the [dependency refresh](evidence/r2-release-verification.md) now records storage PR #3763's commit. I-01b is superseded without implementation by D-018. The [rollout scope record](evidence/rollout-scope-update.md) retains the owner's correction; the earlier dependency record is point-in-time evidence. Keep the existing rollout behavior and validate graceful close, one active writer, bounded startup/lock handling and recovery during P4. No Recreate patch or strategy-selector change is scheduled; live CSI/recovery and service acceptance remain open.

The owner reports the R2/release-tooling changes landed and rollout is in progress. The dependency refresh verifies infraops PR #3764/tag v2.617.0, docker PR #1818's release 8.48/bump 2.617.0 and all four deployment-pipeline source pins. Do not repeat lifecycle, release-image or consumer pin implementation. Actual rollout/execution, storage-preserving releases, bucket/reference configuration and lifecycle activation remain separate evidence. Keep each repository's requirements + original patch + final PR/revisions + actual session ID and accessible session record/export for feedback before advancing. Their original implementation patches/session records and CI/rollout results were not inspected in this refresh; final commits are not substitutes for original patches. Dependency delivery does not complete phase feedback or settle O-003.

At the owner's request, the four historical planning-update patches and their companion base manifests and checksums are omitted from this handoff. Current dependency evidence uses the retained verification summaries and upstream PR/commit references. The capture requirements below apply to future implementation packets.

The handoff cycle for each selected packet is:

1. Record the requirements/input revision, first requirements draft, repository baseline, skills revision and actual agent session ID.
2. The agent produces the scoped change, runs its applicable checks, exports the complete original patch, and hands it to the human with the capture reminder in section 2. The patch includes new files and any necessary binary-change representation; record the base revision and a content hash or immutable patch reference.
3. The human drives further changes, review, and PR creation/finalization. Later assistance follows the human's explicit scope; patch production does not authorize the agent to push, open a PR, merge or proceed to another packet.
4. When the final reviewed PR is available, the human supplies the four-artifact bundle. Inspect the original patch against the final PR and use the accessible session record and review rationale to explain the differences.
5. Review the resulting skill candidates separately in `bin`, record adoption or the no-change/deferred decision, and close the phase feedback record before selecting the next phase.

## 2. Preserve the first draft before revising it

For each review packet, retain the actual first requirements version generated by the agent before owner edits or later agent refinement. This is a per-packet baseline; it is distinct from the installation's current requirements and from the historical snapshots already in `docs/history/`.

When the owner later supplies the requirements, original patch, final PR and session ID, use those exact artifacts as the comparison inputs. Record their provenance. Do not replace the first draft or original patch with a cleaned-up or final version. If an original was not retained, mark that baseline missing; a reconstructed version is labelled as reconstruction and cannot establish what the original agent actually produced.

Capture the following context with the draft:

| Input | What to retain |
| --- | --- |
| Task | Original request, phase/packet ID, allowed repositories, relevant requirement/acceptance IDs, and the scope understood at the start. |
| First requirements | Exact first generated text or an immutable revision containing it, capture time, and source reference. |
| Requirements used | Exact revision/input supplied for patch generation, including owner changes made after the first requirements draft. |
| Original agent patch | Complete patch/snapshot at the agent-to-human handoff, its base commit and content identity, including new files. Keep it immutable through later human refinement. |
| Session ID | Exact drafting/implementation session or thread ID and tool/runtime identity. If several sessions contributed, record each ID with its role and patch/revision; do not invent an ID or assume the inspector can resolve it. |
| Session record | Accessible conversation/export reference when available, with the relevant prompts, visible explanations, tool/check outputs and corrections. Record access limitations or missing portions. |
| Instructions | Applicable repository guidance and the actual `bin` commit/skill paths used. Record explicit invocation and discovery information when available; do not assume a skill was loaded just because it existed. |
| Baseline | Starting repository commits and relevant fixtures/contracts already available to the agent. |
| Runtime | Agent/model/tool context when exposed by the runtime. Mark unavailable information unknown; do not infer it. |

The first-draft copy is immutable. Subsequent proposals and owner decisions belong in later revisions or the comparison record. Redact secret material if necessary, mark the redaction, and keep enough context to explain the correction. Do not copy credentials, environment dumps, browser profiles, or unrelated source trees.

### Session access

A session ID identifies the conversation to inspect; it is not itself the conversation content. Codex documents reading saved thread history by ID, and its hook documentation describes a transcript path that may be absent. For this process, provide access to the corresponding saved session or an available export; do not assume another agent or machine can retrieve it from the ID alone. Do not resume or modify the original session merely to inspect it. [Official stored-thread documentation](https://learn.chatgpt.com/docs/app-server#read-a-stored-thread-without-resuming), [official transcript metadata documentation](https://learn.chatgpt.com/docs/hooks#common-input-fields).

The inspector reports which messages, tool results, review discussions and revisions actually support its explanation. If session content is unavailable, compare requirements/patch/PR but state that the session was not inspected and causal conclusions are limited.

### Reminders at the handoff and phase close

Future agents must include this reminder when handing a patch to the human:

> Before refining this patch into a PR, retain the requirements revision, this original patch and its base commit, and this agent session ID. Once the PR is final, return requirements + original patch + final PR/revisions + session ID for skill-feedback inspection. Keep an accessible session record/export if available.

When the human returns with a final PR or asks to close/advance the phase, remind them to supply or link the four-artifact bundle and record its inspection or explicit missing-evidence disposition. These are workflow reminders in agent handoffs and phase reviews. No scheduled notification, hook, external message or automatic upload is configured by this plan.

## 3. Capture the final PR and why it changed

At the end of each packet, retain the final reviewed PR reference and exact base/head commits; record the merge commit if it has merged. A moving branch name or a PR URL alone is not an immutable implementation snapshot. A final reviewed, unmerged PR is recorded as such rather than described as merged.

Retain or link to:

- The final requirements/acceptance scope and relevant implementation diff at those revisions.
- Owner/reviewer corrections, decisions, and their rationale; identify later scope changes separately from errors in the original draft.
- Actual test/check results and material limitations at the final revision.
- Remaining follow-ups and any behavior intentionally deferred.

If a phase spans several independent PRs, index each requirements/original-patch/final-PR/session bundle. Do not flatten `bin`, `infraops`, and service changes into one synthetic final PR. For a documentation-only packet without a PR, use the accepted document revision and record that no final PR exists; do not invent one.

## 4. Inspect the path from requirements through patch to PR

Use a short comparison table for each packet:

| Requirements statement or omission | Original patch evidence | Final PR evidence | Session/review evidence and reason | Classification / skill candidate |
| --- | --- | --- | --- | --- |
| Exact excerpt/revision or precise reference | Base/revision, file and behavior at agent handoff | Final revision/path and observable change | Actual prompt, correction, check result or owner rationale | Category below, smallest owning skill change, or no skill change |

Classify each material difference before proposing a skill change:

| Category | Response |
| --- | --- |
| Reusable gap in the skill | Identify the smallest owning skill change, supported by the real task and correction. |
| Existing instruction was missed or not discovered | Check invocation, discovery, conflicting instructions, and context. Do not duplicate an already adequate rule merely because an agent failed to follow it. |
| Product-specific decision or new owner direction | Update einblick's contract/examples; keep service-specific policy out of shared skills. |
| Missing evidence, unavailable tooling or environment limitation | Record the limitation and the correct evidence requirement. Do not treat it as proof that a code or skill change would work. |
| Routine implementation choice or wording preference | Record only if useful to explain the PR; it does not itself justify a shared skill rule. |

The final PR is evidence of the accepted result for its supported scope. A difference from the requirements or original patch does not automatically prove a skill defect. Distinguish requirements mistakes from patch-generation mistakes, later owner direction and human review corrections. State the causal explanation and the context the original agent could actually have known, supported by the recorded session/review evidence. Review omissions, unnecessary work, wrong test layers, unsupported assumptions, unclear scope, and missed repository conventions where the record demonstrates them.

## 5. Improve skills in an independent bin review

After the phase's comparisons, group related candidates by the existing skill that owns the behavior. Prepare a separate `bin` skill-improvement change from the product/build/infrastructure changes. Reuse and clarify existing instructions before adding new rules; keep the change applicable to supported consumers beyond einblick. A phase may legitimately produce no skill edit.

For each candidate, document:

1. The requirements/original-patch/final-PR/session bundle and the concrete correction that supports it.
2. The exact owning skill/section and what the current instructions already say.
3. The smallest proposed revision, expected observable improvement, and a supported counterexample or regression risk to check.
4. Validation evidence, remaining uncertainty, and the accept/defer/reject decision.

Follow `bin/AGENTS.md`, its current skill-maintenance guidance and applicable skills when that later task is authorized. Keep shared skills usable by supported agents; update invocation metadata/references when the skill's interface changes. Use `make skills-lint` and the other repository checks applicable to the actual change. Lint checks structure; do not present it as behavioral proof.

The existing [evaluate-skill workflow](https://github.com/alexfalkowski/bin/blob/9372832ac8d265747e347facf9d6a58b7af53ea5/skills/evaluate-skill/SKILL.md) separates source-only inspection from behavioral comparisons. Recheck the current workflow before use. If a comparison is selected later, define outcome assertions from supported usage and follow its authorization/evidence rules. This plan does not grant current-request sub-agent authorization or run a comparison. Claims about behavior must match the evidence actually obtained.

An accepted change is reviewed and versioned in `bin` independently. Before the next selected phase, record the skill revision available to the consuming repository and update its pin when required by the accepted improvement. The next phase's context records whether that revision was actually used. A proposed or unmerged patch must not be reported as adopted. The baseline from the completed phase continues to point to the old instructions it actually used.

## 6. Future evidence layout and templates

Use portable links to immutable evidence wherever sufficient. The following is a proposed layout for evidence created during later phase work; these phase folders and captures have not been created by this planning task:

```text
docs/feedback/
  P0/
    phase-summary.md
    E-01/
      context.md
      requirements-first.md
      requirements-used.md
      agent-first.patch
      session.md
      final-pr.md
      comparison.md
    B-01/
      ...
```

`agent-first.patch` is the immutable patch handed to the human; its base and content identity belong in `context.md`. `session.md` records actual session IDs, their roles, the accessible record/export reference if any, and inspection limitations. `final-pr.md` holds repository/PR references, immutable revisions, final requirements/validation links, review rationale and unresolved limitations; it need not copy a complete source tree or PR discussion. `comparison.md` uses the table in section 4. Add a new record per packet/sub-packet so original artifacts and source revisions remain distinguishable.

A minimal future bundle index is:

```text
Phase / packet:
Requirements first draft:
Requirements revision used for the patch:
Original agent patch / base commit / content identity:
Agent session ID(s) and role(s):
Accessible session record/export, or unavailable:
Human-driven final PR / base-head or merge revision:
Review rationale and final check evidence:
Skills / bin revision used:
Comparison and skill-feedback disposition:
```

Each phase summary records:

| Field | Content |
| --- | --- |
| Phase and state | Phase ID; unstarted, agent patch, human PR refinement, product review, feedback review, or closed. No phase is active in this handoff. |
| Packet evidence | Index of requirements/original-patch/final-PR/session bundles, including missing inputs and unmapped changes. |
| Product outcome | Accepted results, actual checks, remaining acceptance gates and owner decisions. |
| Skill feedback | Supported candidates with their accept/defer/reject rationale; explicit no-change result where appropriate. |
| bin result | Separate skill PR/commit, checks, evidence limits, or a stated deferred/no-change disposition. |
| Adoption | Skill revision to use next, consuming pin/update status and any future verification needed. |
| Phase decision | Owner's review outcome and whether a later phase has been selected. Closing a phase does not start the next. |

A future feedback-only task can use this handoff:

```text
Review the feedback for phase <P> / packet <ID>.
Inputs: the exact first agent-generated requirements at <reference>,
the requirements revision used at <reference>,
the original agent patch at <reference, base commit, content identity>,
the final reviewed PR at <repository, PR, base/head or merge commit>,
the session ID(s) at <runtime, ID, role, accessible record/export reference>,
review rationale/check results, and the bin skill revision used.
Inspect the path from requirements through the original patch and session
to the human-driven final PR; distinguish new owner direction, requirements
errors, patch errors and reusable skill gaps. Report inaccessible evidence.
Identify the smallest owning skill improvements with supporting examples.
Writable scope: <planning feedback records only, or explicitly selected bin
skill paths when implementation is part of this later task>.
Follow the current bin guidance for evaluation, changes and validation.
Report missing evidence and proposal/adoption status honestly.
Keep the product PR and bin skill PR separate. Do not start the next phase.
```

## 7. Completion of the feedback loop

For each phase, the feedback loop is complete when its actual requirements/original-patch/final-PR/session bundles are traceable, material corrections have evidence-based explanations, shared-skill candidates have a reviewed disposition, any accepted `bin` change has appropriate validation and an adoption record, and the next phase's intended instruction revision is identified. Missing evidence and an unavailable session record remain visible. No phase completion is inferred from this document, and no bin skill improvement has been executed during planning.
