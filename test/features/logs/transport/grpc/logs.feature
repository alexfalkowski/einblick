@storage
Feature: Durable local logs
  Local clients receive success after their complete export commits locally.
  Records retain their content and exact times after the service reopens storage.

  Scenario Outline: Persist representative logs with their resource, scope and typed values
    Given a representative local log export
    When the client exports logs using "<compression>" compression
    Then the log export should succeed without partial success
    And local diagnostics should report the exact committed log count
    And the server should not print telemetry for this export
    And log diagnostics should not contain the export payload
    And the complete log export should survive a "graceful" restart
    And stored log timestamps should follow the log time policy

    Examples:
      | compression |
      | none        |
      | gzip        |

  Scenario Outline: Record-free exports leave local storage unchanged
    Given a log export with "<context>" and no records
    When the client exports logs using "gzip" compression
    Then the log export should succeed without partial success
    And local diagnostics should report the exact committed log count
    And no logs should have been stored for this export
    And existing local records and context should be unchanged

    Examples:
      | context                    |
      | no context                 |
      | resource and scope context |

  Scenario: Receive a larger log batch
    Given a log export containing 129 records
    When the client exports logs using "none" compression
    Then the log export should succeed without partial success
    And local diagnostics should report the exact committed log count
    And the complete log export should survive a "graceful" restart

  Scenario: Receive a larger log body
    Given a log export with a 65536 byte body
    When the client exports logs using "none" compression
    Then the log export should succeed without partial success
    And the complete log export should survive a "graceful" restart

  Scenario Outline: The shared transport rejects oversized messages
    Given a log export with a 1000001 byte body
    When the client exports logs using "<compression>" compression
    Then the log export should fail with "RESOURCE_EXHAUSTED"
    And the server should not print telemetry for this export
    And log diagnostics should not contain the export payload
    And no logs should have been stored for this export

    Examples:
      | compression |
      | none        |
      | gzip        |

  Scenario: A valid export succeeds after a malformed request
    Given a malformed log export has been rejected
    When a valid empty export follows
    Then the log export should succeed without partial success

  Scenario: Acknowledged logs survive an interrupted process
    Given a representative local log export
    When the client exports logs using "gzip" compression
    Then the log export should succeed without partial success
    And the complete log export should survive an "interrupted" restart
    And stored log timestamps should follow the log time policy

  Scenario Outline: Select log time without changing the original timestamps
    Given a log export with timestamp <timestamp> and observed timestamp <observed>
    When the client exports logs using "none" compression
    Then the log export should succeed without partial success
    And the complete log export should survive a "graceful" restart
    And stored log timestamps should follow the log time policy

    Examples:
      | timestamp            | observed             |
      | 0                    | 1795086245123456799  |
      | 0                    | 0                    |
      | 1                    | 1795086245123456799  |
      | 18446744073709551615 | 0                    |
      | 0                    | 18446744073709551615 |

  Scenario: Store typed log bodies and optional resource and scope context
    Given a log export with every supported body type and optional context
    When the client exports logs using "none" compression
    Then the log export should succeed without partial success
    And the complete log export should survive a "graceful" restart
    And stored log timestamps should follow the log time policy
    And only resource and scope context for stored records should be allocated

  Scenario: Retain duplicate exports as additional records
    Given a representative local log export
    When the client exports the same logs twice
    Then both log exports should succeed without partial success
    And the stored logs should contain 2 copies of the complete export

  Scenario: Unwritable storage rejects the complete export without changing stored records
    Given acknowledged local logs
    And a representative local log export
    When the client exports logs without a writable local disk
    Then the log export should fail with "UNAVAILABLE"
    And local diagnostics should identify a log commit failure
    And log failure diagnostics should not contain the export payload
    And no logs should have been stored for this export
    And existing local records and context should be unchanged

  Scenario: A later storage failure rejects every resource and record in an export
    Given acknowledged local logs
    And a log export spanning multiple resources with a conflicting later record
    When the client exports logs with a later storage write rejected
    Then the log export should fail with "UNAVAILABLE"
    And no logs should have been stored for this export
    And existing local records and context should be unchanged

  Scenario: A rejected multi-resource export can be retried after repairing storage
    Given acknowledged local logs
    And a multi-resource log export was rejected by a later storage write
    When the client exports logs using "none" compression
    Then the log export should succeed without partial success
    And the complete log export should survive a "graceful" restart
    And previously acknowledged records and context should be unchanged

  Scenario: A rejected export can be retried after storage recovers
    Given a log export was rejected while local storage was unwritable
    When the client exports logs using "none" compression
    Then the log export should succeed without partial success
    And the complete log export should survive a "graceful" restart

  Scenario: Initialize log storage in an existing database without log tables
    Given a local database with unrelated data and no log tables
    When the server initializes a database without log tables
    Then log storage should be initialized without changing unrelated data

