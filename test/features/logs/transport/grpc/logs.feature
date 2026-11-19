@printing
Feature: Development log receipt
  Local clients receive a receipt response and can inspect their logs in server output.
  This development receiver discards records after printing them.

  Scenario Outline: Print representative logs with their resource, scope and typed values
    Given a representative local log export
    When the client exports logs using "<compression>" compression
    Then the log export should succeed without partial success
    And the server should print the complete log export

    Examples:
      | compression |
      | none        |
      | gzip        |

  Scenario: Receive an empty export
    Given an empty log export
    When the client exports logs using "gzip" compression
    Then the log export should succeed without partial success
    And the server should print the complete log export

  Scenario: Receive a larger log batch
    Given a log export containing 129 records
    When the client exports logs using "none" compression
    Then the log export should succeed without partial success
    And the server should print the complete log export

  Scenario: Receive a larger log body
    Given a log export with a 65536 byte body
    When the client exports logs using "none" compression
    Then the log export should succeed without partial success
    And the server should print the complete log export

  Scenario Outline: The shared transport rejects oversized messages
    Given a log export with a 1000001 byte body
    When the client exports logs using "<compression>" compression
    Then the log export should fail with "RESOURCE_EXHAUSTED"
    And the server should not print telemetry for this export

    Examples:
      | compression |
      | none        |
      | gzip        |

  Scenario: A valid export succeeds after a malformed request
    Given a malformed log export
    When the client exports logs using "none" compression
    Then the log export should fail with "INTERNAL"
    When a valid empty export follows
    Then the log export should succeed without partial success

