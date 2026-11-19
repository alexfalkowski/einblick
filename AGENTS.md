# AGENTS.md

## Shared guidance

Use `bin/AGENTS.md` for shared skills and cross-repository defaults.

## Architecture and simplicity

Before implementation, inspect both the closest existing service under
`~/code` and the relevant go-service implementation. Bezeichner, Standort and
Migrieren are gRPC references; Web is the MVC reference. Compare the local
`~/code/go-service` checkout with the version pinned by this service before
relying on a capability. Check the caller, package ownership, dependency
direction, module/constructor/registration pattern, configuration projections,
lifecycle, transport and dominant test harness. Record concrete reference paths
and consumed revisions with the change.

Keep each step to its agreed feature behavior. Reuse go-service and existing
service patterns before adding anything new. Additional custom limits,
thresholds, guards, settings, architectural layers or policies require an
explicit owner decision; do not introduce them speculatively, including as
hardcoded constants.

Keep constructors and registration direct for the supported configuration.
Put necessary settings validation in the owning configuration. Do not duplicate
framework validation or add dependency nil checks for unsupported wiring.
Define an error at package scope only when callers need a reusable sentinel or
an exported error contract; otherwise create it at the failure site.

Extract small helpers for genuinely shared behavior. Do not add abstractions
for hypothetical future requirements.

## Feature tests

Never call another Cucumber step from a step definition, including through
`step` or `steps`. Reuse plain Ruby helper methods, fixture builders or existing
client abstractions instead. Step definitions should describe setup, an action
or an assertion without depending on another step's wording.

Keep the existing Ruby/Cucumber/Nonnative harness and lifecycle. Shared scenario
setup and actions belong in Cucumber World modules under `test/lib`, registered
with `World(...)` in the feature support code. Do not leave helper methods in
step-definition files.

Centralize test-library dependency requires in `test/lib/einblick.rb`.
Helper and World files do not require their own dependencies.

Use the existing RSpec matchers for assertions. When a feature needs a new kind
of matching, extend RSpec with a custom matcher in the support code instead of
embedding parsing or bespoke matching logic in steps or World action helpers.
Keep feature assertions and scenarios intact when refactoring shared setup.

Scope scenarios to behavior owned by the feature being implemented. Do not add
checks for unrelated or absent services, future features or framework behavior
outside that feature's contract. Negative cases must exercise the feature's own
supported entrypoint.

## Documentation

Follow Abgleich's README and documentation layout under `~/code/abgleich`.
Keep the README accessible: a short introduction, current capabilities,
a runnable quickstart and links to focused pages under `docs/`. Put detailed
feature behavior, configuration, operations and development guidance in those
pages instead of expanding the README. Preserve important usage and data-loss
information when moving content, and update incoming links.

Use a relevant emoji prefix on titles and section headings in every README,
matching the other services. Keep the heading text understandable without the emoji.
Distinguish implemented behavior from planned features throughout the docs.

## Implementation workflow

Use [docs/review-and-plan.md](docs/review-and-plan.md) as the feature queue and
saved state, and [docs/requirements.md](docs/requirements.md) as the product
contract. Keep agent instructions and process in this file; the plan contains
feature work, dependencies, acceptance evidence and progress.

Focus the implementation queue on product features and their repository
validation. The owner handles deployment and service cutover; do not track
those tasks or make them prerequisites for feature work.

Number implementation steps consecutively: `E-01`, `E-02`, `E-03`, and so on.
Use the next whole number for each step, including split or inserted work.
Renumber pending steps in execution order and update their references together.
Keep completed step IDs and their evidence unchanged; do not add letter suffixes.

Each continuation handles exactly one step, then stops:

1. Read the saved state and first remaining row. Resume an in-progress or blocked
   step rather than skipping it. Verify its repository state and prerequisites.
2. Set the status to `in progress`; implement only that step with its relevant
   requirements, validation and documentation.
3. On interruption or validation failure, leave the step in the queue and save
   actual commands/results, remaining work and blockers. Set `in progress` or
   `blocked` as appropriate.
4. When its feature gates pass, preserve the original patch/base and record a
   concise completion entry: result, actual validation, acceptance portions,
   dependency/instruction revisions, handoff references, feedback disposition
   and remaining gates. Mark unavailable evidence explicitly.
5. Remove the completed row, select the next first row, set it to `ready`, update
   resume notes and the last completed step, then stop. Owner review remains the
   next step's entry condition; do not implement it in the same request.
6. Once the queue and readiness gates are complete, retain final acceptance and
   recovery evidence, delete the plan and update incoming links. Keep the product
   specification.

Work serially through the phases, one step and writable repository at a time.
Distinguish proposals from agreed choices and update affected requirements when
choices change. Only material decisions needed by the selected step block it.
Read-only references do not authorize sibling edits. Publishing, deployment and
client enablement require explicit scope; dependency completion does not
activate a consumer. Follow the active runtime's delegation rules.

For UI work, preserve the initial design reference and iterate in the working
MVC service with real data. Do not create another prototype server.

## Validation

Use the owning repository's instructions, Makefile and CI to select commands.
Use the README and `make help` for service checks. For documentation changes,
run from this repository root:

```sh
python3 tools/check_handoff.py
```

This checks local Markdown targets, requirement/acceptance references and
embedded preview assets/license. It does not validate backend or browser
behavior. Links into uninitialized submodules are reported as skipped.

## Patch handoff and feedback

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
