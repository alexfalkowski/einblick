@site
Feature: Investigate recent logs in the browser
  Operators search acknowledged logs and inspect their original telemetry context.

  Scenario: Open recent logs without a sign-in flow
    When I open the Logs page
    Then I should see the recent log controls without a sign-in flow
    And I should see time presets, UTC pickers and the five severity choices

  Scenario: Replace a saved time range with a recent preset
    Given acknowledged searchable logs
    When I choose the last hour
    Then the query link should fix a one-hour window ending now for the selected service

  Scenario: Preserve exact bounds when submitting a saved search
    Given acknowledged searchable logs
    When I submit the displayed UTC picker values
    Then I should see the selected service's log messages and exact event times
    And the query link should retain the original fractional seconds

  Scenario: Set a custom UTC range
    Given acknowledged searchable logs
    When I set the UTC pickers to "2026-11-19T11:04" and "2026-11-19T11:04:04"
    Then the query link should use the selected UTC bounds
    And I should see a readable range with no matching logs

  Scenario Outline: Read logs in the preferred browser language
    Given acknowledged searchable logs
    When I investigate them in a "<layout>" view with browser languages "<preferences>"
    Then I should see the "<layout>" log view in "<language>"
    And I should see the selected service's log messages and exact event times

    Examples:
      | layout  | preferences                   | language |
      | full    | en-GB                         | en       |
      | full    | en;q=0.5,de-AT;q=0.9          | de       |
      | full    | es-MX,en;q=0.5                | es       |
      | full    | fr-CA                         | en       |
      | partial | fr;q=oops                     | en       |
      | partial | en;q=0.3,es;q=0.6,de-CH;q=0.8 | de       |
      | partial | es-AR                         | es       |

  Scenario Outline: Submit fixed filters and retain those filters in the query link
    Given acknowledged searchable logs
    When I submit the browser filters <filters>
    Then I should only see the log message "<message>" with severity "<displayed severity>"
    And the query link should preserve the submitted filters and absolute time range

    Examples:
      | filters                                         | message                | displayed severity |
      | {"text":"%_"}                                   | literal %_ ' OR 1=1 -- | WARN (INFO)        |
      | {"severity":"ERROR"}                            | same-time second       | ERROR (INFO)       |
      | {"trace_id":"0102030405060708090a0b0c0d0e0f10"} | same-time first        | INFO               |

  Scenario: Inspect markup-like log content and its typed values as text
    Given an acknowledged log with markup-like content
    When I investigate it in a partial view
    Then I should see the original message, service and typed log details as text

  Scenario: Inspect logs with blank messages
    Given acknowledged logs with blank messages
    When I investigate them in a "full" view with browser languages "de"
    Then I should see German labels for their details and the original blank values

  Scenario: Continue a selected query in bounded pages
    Given acknowledged searchable logs
    When I read the selected logs in two-record pages
    Then I should see each matching log once in newest-first order

  Scenario: Inspect exact timestamps at the top of the OTLP time range
    Given acknowledged logs beyond the signed nanosecond range
    When I investigate them in a "full" view with browser languages "en"
    Then I should see the selected service's log messages and exact event times

  Scenario Outline: Distinguish no matches from an invalid time range
    Given acknowledged searchable logs
    When I investigate with "<outcome>" in a "<layout>" view with browser languages "<preferences>"
    Then the "<layout>" view should show "<outcome>" in "<language>" with HTTP <code>

    Examples:
      | outcome | layout  | preferences | language | code |
      | empty   | full    | en          | en       | 200  |
      | empty   | partial | de          | de       | 200  |
      | empty   | partial | es          | es       | 200  |
      | invalid | full    | es          | es       | 400  |
      | invalid | partial | de          | de       | 400  |
      | invalid | partial | en          | en       | 400  |

  Scenario: Storage unavailability is visible and a later query succeeds
    Given acknowledged searchable logs
    When I submit a query while local log storage is unavailable and try again after recovery
    Then the failed query should show that local storage is unavailable in German
    And the later query should show the selected service's log messages and exact event times

  Scenario: An expired query shows a timeout without displaying a partial result
    Given acknowledged searchable logs
    When my Spanish log query exhausts its budget
    Then I should see a Spanish log timeout
