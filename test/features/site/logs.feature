@site
Feature: Investigate recent logs in the browser
  Operators search acknowledged logs and inspect their original telemetry context.

  Scenario: Open recent logs without a sign-in flow
    When I open the Logs page and load its assets
    Then I should see the recent log controls without a sign-in flow
    And I should see the available time presets and the five severity choices
    And the stylesheet and script URLs should identify the content they serve
    And I should see the Einblick icon in the browser tab

  Scenario Outline: Replace a saved time range with a recent preset
    Given acknowledged searchable logs
    When I choose the "<preset>" time range
    Then the query link should fix the "<preset>" window of <hours> hours ending now for the selected service

    Examples:
      | preset | hours |
      | 1 hour | 1     |
      | 3 days | 72    |
      | 7 days | 168   |

  Scenario Outline: Search using the only preset within a short query limit
    When I choose "<preset>" with a <minutes>-minute query limit
    Then "<preset>" should be the only available preset and should search the last <minutes> minutes

    Examples:
      | preset | minutes |
      | Recent | 14      |
      | 15 min | 15      |

  Scenario: Preserve exact bounds when submitting a saved search
    Given acknowledged searchable logs
    When I submit the displayed search filters
    Then I should see the selected service's log messages and exact event times
    And the query link should retain the original fractional seconds

  Scenario Outline: Search again after new logs arrive
    Given acknowledged searchable logs
    When I repeat a search for the "<range>" range after a new log arrives in the "<layout>" view
    Then the new log should appear in a refreshed "<preset>" window of <hours> hours

    Examples:
      | range   | layout  | preset | hours |
      | default | partial | 7 days | 168   |
      | 1 hour  | partial | 1 hour | 1     |
      | 1 hour  | full    | 1 hour | 1     |

  Scenario: Clear a filter and refresh recent logs without htmx
    Given acknowledged searchable logs
    When I clear the message filter before rerunning a one-hour search after a new log arrives
    Then clearing the filter should keep the exact time bounds
    And the next search should show the new log in a refreshed one-hour window

  Scenario: Open a saved search with a custom time range
    Given acknowledged searchable logs
    When I open a saved search from "2026-11-19T11:04:00Z" to "2026-11-19T11:04:04Z"
    Then the saved time range should be applied
    And I should see no matching logs

  Scenario Outline: Open a bookmark from the old UTC form
    Given acknowledged searchable logs
    When I open an old bookmark with UTC picker bounds "<start>" and "<end>"
    Then the search should use the exact bounds "<applied start>" and "<applied end>"

    Examples:
      | start               | end                 | applied start                  | applied end                    |
      | 2026-11-19T11:04:05 | 2026-11-19T11:04:05 | 2026-11-19T11:04:05.123456789Z | 2026-11-19T11:04:05.123456799Z |
      | 2026-11-19T11:04    | 2026-11-19T11:04:06 | 2026-11-19T11:04:00Z           | 2026-11-19T11:04:06Z           |

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
    When I search for the literal markup in that message
    Then I should see the original message, service and typed log details as text

  Scenario Outline: Clear a message search with no matches
    Given acknowledged searchable logs
    When I clear a message search with no matches in the "<layout>" view
    Then I should see which text had no matches and how to clear it
    And the "<layout>" view should show warnings in the same time range for the selected service

    Examples:
      | layout  |
      | partial |
      | full    |

  Scenario: Inspect logs with blank messages
    Given acknowledged logs with blank messages
    When I investigate them in a "full" view with browser languages "de"
    Then I should see German labels for their details and the original blank values

  Scenario Outline: Inspect the reported status and duration of a request
    Given an acknowledged "<protocol>" request log with status "<status>" and duration "235.055614ms"
    When I investigate it in the Logs page
    Then the inspector should show "<label>" as "<status>" and the duration as "235.06 ms"

    Examples:
      | protocol | status      | label       |
      | HTTP     | 200         | HTTP status |
      | gRPC     | Unavailable | gRPC status |

  Scenario: Continue a selected query in bounded pages
    Given acknowledged searchable logs
    When I read the selected logs in two-record pages
    Then I should see each matching log once in newest-first order

  Scenario: Search and page through filtered logs when htmx is unavailable
    Given acknowledged recent logs with matching requests and other messages, severities and traces
    When I choose the last hour and follow Next page without htmx
    And I rerun the paged search after a matching log arrives
    Then the full pages should show "same-time first" followed by "first" in the same filtered search
    And the next search should show the new matching log in a refreshed one-hour window

  Scenario: Find related logs from a later page
    Given acknowledged logs with related requests of different severities and messages
    When I find related logs from a later page of an active message and severity search
    Then I should see the matching trace with the same time range and filters

  Scenario: Inspect exact timestamps at the top of the OTLP time range
    Given acknowledged logs beyond the signed nanosecond range
    When I investigate them in a "full" view with browser languages "en"
    Then I should see the selected service's log messages and exact event times

  Scenario: Inspect logs without an original event time
    Given acknowledged logs without an event time, one with an observation time
    When I investigate them in a "full" view with browser languages "en"
    Then the inspector should distinguish observation time from receipt time and show the exact timestamps

  Scenario Outline: See how to recover from an empty or rejected search
    Given acknowledged searchable logs
    When I investigate with "<outcome>" in a "<layout>" view with browser languages "<preferences>"
    Then the "<layout>" view should show "<outcome>" in "<language>" with HTTP <code>

    Examples:
      | outcome            | layout  | preferences | language | code |
      | empty              | full    | en          | en       | 200  |
      | empty              | partial | de          | de       | 200  |
      | empty              | partial | es          | es       | 200  |
      | broken link        | full    | es          | es       | 400  |
      | broken link        | partial | en          | en       | 400  |
      | dates out of order | partial | de          | de       | 400  |
      | dates out of order | partial | en          | en       | 400  |
      | invalid dates      | partial | en          | en       | 400  |
      | wide date range    | partial | en          | en       | 400  |
      | invalid filter     | partial | en          | en       | 400  |

  Scenario: Storage unavailability is visible and a later query succeeds
    Given acknowledged searchable logs
    When I submit a query while local log storage is unavailable and try again after recovery
    Then the failed query should show that local storage is unavailable in German
    And the later query should show the selected service's log messages and exact event times

  Scenario: An expired query shows a timeout without displaying a partial result
    Given acknowledged searchable logs
    When my Spanish log query exhausts its budget
    Then I should see a Spanish log timeout
