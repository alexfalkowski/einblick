@storage @migration
Feature: Versioned local schema migrations
  Startup applies the binary's embedded migrations before serving clients.
  Restarts preserve records and failed migrations never advance the schema.

  Scenario: Starting again leaves the applied migration and records unchanged
    Given acknowledged logs in the current schema
    When the server reopens an up-to-date schema
    Then migration history and stored records should be unchanged

  Scenario: Upgrade an existing log database to support archival
    Given acknowledged logs in the previous schema
    When the server upgrades the log database
    Then migration history should record schema version 5
    And the upgrade should preserve the acknowledged logs

  Scenario: Retry the archival upgrade after a schema conflict is repaired
    Given acknowledged logs in the previous schema
    When a schema conflict interrupts the archival upgrade and is repaired
    Then the failed archival upgrade should leave the previous schema and logs intact
    And migration history should record schema version 5
    And the upgrade should preserve the acknowledged logs

  Scenario: Reject a newer Goose schema without rewriting data or history
    When the server attempts to open a newer migration history
    Then startup should reject the newer migration history without changing storage

  Scenario: Retry the publication upgrade after a schema conflict is repaired
    Given acknowledged logs in the staging schema
    When a schema conflict interrupts the publication upgrade and is repaired
    Then the failed publication upgrade should leave the staging schema and logs intact
    And migration history should record schema version 5
    And the upgrade should preserve the acknowledged logs

  Scenario: Roll back schema changes after a failed migration and retry after repair
    When a schema conflict interrupts migration and is repaired
    Then startup should fail without committing the migration's schema changes
    And migration history should record schema version 0 at the failure
    And the conflicting schema and unrelated data should remain intact
    And migration history should record schema version 5
    And the server should accept and persist a new log export
