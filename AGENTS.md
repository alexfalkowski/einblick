# AGENTS.md

## Shared guidance

Use `bin/AGENTS.md` for shared skills and cross-repository defaults.

## Accepted design

Before recording a finding, audit entry or proposed change, read the
[accepted-design index](docs/agents/accepted-design.md) and its relevant
area files. Apply the recorded scope of each decision. Add owner-accepted
design choices, tradeoffs and dependency limitations to the relevant area file
as they are agreed.

## Architecture and simplicity

Before implementation, inspect both the closest existing service under
`~/code` and the relevant go-service implementation. Bezeichner, Standort and
Migrieren are gRPC references; Web is the MVC reference. Compare the local
`~/code/go-service` checkout with the version pinned by this service before
relying on a capability. Check the caller, package ownership, dependency
direction, module/constructor/registration pattern, configuration projections,
lifecycle, transport and dominant test harness. Keep concrete reference paths
and consumed revisions in review evidence.

When a feature spans multiple concerns, sketch the call path and identify who
owns each resource, state transition and lifecycle before editing. Let the
feature service define the domain values and operations it needs from its
adapters. Wire concrete adapters in the enclosing module. Check the import
direction and call sites along with the file layout. For log export, archive
owns batch identity and export policy, storage owns durable state, staging owns
Parquet files and workspace recovery, and the worker owns scheduling.

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

In Go code, use go-service's `strings.IsEmpty` for empty-string checks and
`strings.Empty` for empty-string values.

Keep diagnostic logging in separate decorators in `logging.go`, following
Abgleich's `internal/github/logging.go` and `internal/github/service.go`.
Do not mix diagnostic logger calls into transport handlers, persistence methods
or business rules. Compose logging around the operation interface in the owning
constructor or module. Preserve the operation's context, inputs, results, errors
and lifecycle; emit successful outcomes only after the operation succeeds.
Apply this pattern when introducing or extracting diagnostics in future work.

## SQL naming

For application-owned schemas, use unquoted `lower_snake_case` identifiers and
descriptive words rather than compressed names such as `tstamp`. Name SQL
timestamp columns for their event, such as `created_at` or `applied_at`. Keep
explicit units for integer time values, such as `received_timestamp_ns`.

Name boolean columns as clear, positive predicates. Prefixes such as `is_` and
`has_` are acceptable when they make the meaning clear, for example `is_archived`
and `has_errors`; avoid negative names and double negatives. Follow the existing
domain vocabulary rather than imposing or banning a prefix mechanically.

The DuckDB migration-history adapter records application through row presence
and `applied_at`. Derive Goose's required boolean query results from row
presence rather than storing a redundant flag. Preserve its query parameter
and result order and migration-state semantics in the adapter.

Before the first release, refine the bootstrap schema and migration-history
adapter directly. Do not add compatibility migrations, legacy-schema fallbacks
or upgrade documentation for unreleased changes unless the owner requests them.
Keep disposable test databases aligned with the current schema. After release,
preserve applied migrations and use new numbered migrations for schema changes.

## Feature tests

Write Cucumber scenarios from a user or operator perspective, describing one
coherent behavior rather than a list of implementation tasks. Keep setup in
Given, actions in When and assertions in Then, with And/But extending the
current phase. Never return to setup or actions after assertions. Keep process,
fixture and storage-inspection mechanics in World helpers behind meaningful
behavior steps.

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

Write project documentation for contributors and operators: actionable tasks
and non-obvious behavior specific to Einblick. Configuration guidance covers
this service's additions and pitfalls; do not restate shared go-service settings.
Keep cross-repository comparisons, revision inventories
and agent verification notes in review evidence. Link to dependency manifests,
lockfiles and CI configuration for versions instead of repeating them in prose;
include an exact version only when an instruction or compatibility rule needs it.

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

Keep the plan focused on unfinished work, the next action, unresolved decisions
and missing acceptance evidence. Do not duplicate changes, commit/PR history or
completed refinements that can be derived from Git. Keep necessary handoff
context directly in the Markdown plan. Remove completed features and their notes,
and identify the next pending step. Each step is one bounded feature increment.
Once its agreed scope is complete, advance the step number. Further feature work
belongs to the next increment; do not keep a completed ID open for later stages.

Focus the implementation queue on product features and their repository
validation. The owner handles deployment and service cutover; do not track
those tasks or make them prerequisites for feature work.

Number implementation steps consecutively: `E-01`, `E-02`, `E-03`, and so on.
Use the next whole number for each step, including split or inserted work.
Renumber pending steps in execution order and update their references together.
Never reuse completed step IDs or add letter suffixes.

Each continuation handles exactly one step, then stops:

1. Read the saved state and first remaining row. Resume an in-progress or blocked
   step rather than skipping it. Verify its repository state and prerequisites.
2. Set the status to `in progress`; implement only that step with its relevant
   requirements, validation and documentation.
3. On interruption or validation failure, leave the step in the queue. Record
   remaining work, blockers and any actual commands/results needed to resume
   directly in the Markdown plan. Set `in progress` or `blocked` as appropriate.
4. When its feature gates pass, report the result and actual validation. Keep
   only acceptance or recovery context still needed by remaining work directly
   in the Markdown plan; do not add a completed-feature history.
5. Remove the completed row and its notes, select the next first row, set it to
   `ready`, update the next action and resume notes, then stop. Owner review
   remains the next step's entry condition; do not implement it in the same request.
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

## Handoff and feedback

The Markdown implementation plan is the durable handoff. Put everything needed
for continuation directly in that file: unresolved decisions, remaining work,
acceptance gaps and validation observations still needed by pending features.
Use exact commands and concise actual results when they matter to the next step.
Mark unavailable evidence explicitly.

Do not rely on ignored report files or separate handoff folders. `test/reports/`
is disposable and may be deleted. Do not leave required context behind a link
to those files. Use Git for changes, revisions and review history instead of
copying them into the plan. Remove completed-feature notes once no remaining
work depends on them.

The human drives refinement and the PR stage. When feedback review is needed,
compare requirements with the available changes and review evidence. Separate
owner decisions from patch errors, missing instructions and environment limits.
State missing evidence rather than inventing or reconstructing it.

Propose only the smallest supported change to an existing owning bin skill;
keep service-specific policy here. Skill changes require independent review and
validation in bin. Adoption requires a reviewed/versioned change and the next
feature's actual consumed revision. Feedback review does not authorize skill
edits, publishing, deployment or external messages.
