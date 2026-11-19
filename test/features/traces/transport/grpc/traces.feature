@printing
Feature: Development trace receipt
  Local clients receive a receipt response and can inspect their traces in server output.
  This development receiver discards records after printing them.

  Scenario Outline: Print representative traces with their resource, scope and typed values
    Given a representative local trace export
    When the client exports traces using "<compression>" compression
    Then the trace export should succeed without partial success
    And the server should print the complete trace export

    Examples:
      | compression |
      | none        |
      | gzip        |

  Scenario: Receive an empty export
    Given an empty trace export
    When the client exports traces using "gzip" compression
    Then the trace export should succeed without partial success
    And the server should print the complete trace export

  Scenario: A valid export succeeds after a malformed request
    Given a malformed trace export
    When the client exports traces using "none" compression
    Then the trace export should fail with "INTERNAL"
    When a valid empty export follows
    Then the trace export should succeed without partial success
