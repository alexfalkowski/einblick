@storage @migration
Feature: Versioned local schema migrations
  Startup applies the binary's embedded migrations before serving clients.
  Restarts preserve records and failed migrations never advance the schema.

  Scenario: Starting again leaves the applied migration and records unchanged
    Given a representative local log export
    When the client exports logs using "gzip" compression
    Then the log export should succeed without partial success
    When the server reopens an up-to-date schema
    Then migration history and stored records should be unchanged

  Scenario: Reject a newer Goose schema without rewriting data or history
    When the server attempts to open a newer migration history
    Then startup should reject the newer migration history without changing storage

  Scenario: Roll back schema changes after a failed migration and retry after repair
    When a schema conflict interrupts migration and is repaired
    Then startup should fail without committing the migration's schema changes
    And migration history should record schema version 0 at the failure
    And the conflicting schema and unrelated data should remain intact
    And migration history should record schema version 1
    And the server should accept and persist a new log export
