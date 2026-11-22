# Accepted design

This index records owner-accepted design choices, tradeoffs and dependency
limitations for agents working on Einblick. The area files carry the same
weight as [AGENTS.md](../../AGENTS.md).

Before recording a finding, audit entry or proposed change, read the relevant
area files and account for the decision and its scope. Revisit a decision when
the owner asks or new evidence changes the documented impact.

- [Archive](accepted-design/archive.md) covers DuckDB extension setup and
  cancellation, staging mounts, and R2 publication endpoints and shutdown.
- [Log queries](accepted-design/log-queries.md) covers the repository admission
  boundary and the deferred response resource policy.
