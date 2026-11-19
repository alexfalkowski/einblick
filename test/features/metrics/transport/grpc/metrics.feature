@printing
Feature: Development metric receipt
  Local clients receive a receipt response and can inspect their metrics in server output.
  This development receiver discards records after printing them.

  Scenario Outline: Print representative metrics with their resource, scope and typed values
    Given a representative local metric export
    When the client exports metrics using "<compression>" compression
    Then the metric export should succeed without partial success
    And the server should print the complete metric export

    Examples:
      | compression |
      | none        |
      | gzip        |

  Scenario: Receive an empty export
    Given an empty metric export
    When the client exports metrics using "gzip" compression
    Then the metric export should succeed without partial success
    And the server should print the complete metric export

  Scenario: A valid export succeeds after a malformed request
    Given a malformed metric export
    When the client exports metrics using "none" compression
    Then the metric export should fail with "INTERNAL"
    When a valid empty export follows
    Then the metric export should succeed without partial success
