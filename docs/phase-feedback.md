# Phase feedback and patch handoff

Work through P0–P4 one phase and one selected packet at a time, following
[the implementation plan](review-and-plan.md). The agent produces the change and
original patch; the human drives refinement and the PR stage.

## Capture at patch handoff

Retain immutable references to these inputs for each packet:

| Input | Required context |
| --- | --- |
| Task and requirements | Packet/scope, exact first agent-generated requirements if any, and the requirements revision actually used. |
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

## Review before the next phase

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

At phase close, record product acceptance and remaining gates, packet bundle
references, material corrections, feedback disposition and instruction revision
for the next phase. Missing feedback cannot conceal an unmet product gate.
The owner selects the next phase; feedback review does not itself authorize
skill edits, publishing, deployment or external messages.
