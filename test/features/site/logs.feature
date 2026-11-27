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
    Then the query link should preserve the "<preset>" window of <minutes> minutes ending now for the selected service

    Examples:
      | preset   | minutes |
      | 15 min   | 15      |
      | 1 hour   | 60      |
      | 24 hours | 1440    |
      | 3 days   | 4320    |
      | 7 days   | 10080   |

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
    And the results should retain the original fractional seconds

  Scenario: Reopen and resubmit a custom search before paging
    Given acknowledged searchable logs
    When I reopen a custom time range, press Search, and continue to the next page
    Then the exact custom time range and matching logs should survive resubmission and paging

  Scenario: Count matching logs across a bucket boundary in a paged search
    Given acknowledged matching logs immediately before and on a bucket boundary
    When I view activity for a message search displayed one log at a time
    Then the chart should count both matching logs in adjacent labelled buckets

  Scenario: Inspect an activity bucket clipped within a minute
    When I load activity for a range ending mid-minute
    Then the minute bucket tooltip should show rounded times and its search should keep the exact endpoints

  Scenario: Report invalid bounds when loading log activity
    When I request activity with invalid time bounds
    Then activity should report an invalid search

  Scenario Outline: Clear the message filter while editing custom dates
    Given acknowledged searchable logs
    When I edit the dates for a "<range>" search and clear its message filter
    Then the message filter should clear while the "<range>" interval stays applied

    Examples:
      | range   |
      | fixed   |
      | rolling |

  Scenario Outline: Search again after new logs arrive
    Given acknowledged searchable logs
    When I repeat a search for the "<range>" range after a new log arrives in the "<layout>" view
    Then the new log should appear in a refreshed "<preset>" window of <hours> hours

    Examples:
      | range   | layout  | preset | hours |
      | default | partial | 1 hour | 1     |
      | 1 hour  | partial | 1 hour | 1     |
      | 1 hour  | full    | 1 hour | 1     |

  Scenario: Reload a recent search link after new logs arrive
    Given acknowledged searchable logs
    When I reload the "15 min" search link after a new log arrives
    Then the new log should appear in the last 15 minutes

  Scenario: Clear a filter and refresh recent logs without htmx
    Given acknowledged searchable logs
    When I clear the message filter before rerunning a one-hour search after a new log arrives
    Then clearing the filter should keep the exact time bounds
    And the next search should show the new log in a refreshed one-hour window

  Scenario Outline: Open a saved search with an absolute time range
    Given acknowledged searchable logs
    When I open a saved search from "<start>" to "<end>"
    Then the saved time range should be applied
    And I should see no matching logs

    Examples:
      | start                | end                  |
      | 2026-11-19T11:04:00Z | 2026-11-19T11:04:04Z |
      | 2026-11-19T10:30:00Z | 2026-11-19T10:45:00Z |

  Scenario Outline: Submit the Custom picker with native UTC input values
    Given acknowledged searchable logs
    When I submit Custom picker dates "<start>" and "<end>"
    Then the Custom search should use the exact bounds "<applied start>" and "<applied end>"

    Examples:
      | start               | end                 | applied start                  | applied end                    |
      | 2026-11-19T11:04:05 | 2026-11-19T11:04:05 | 2026-11-19T11:04:05.123456789Z | 2026-11-19T11:04:05.123456799Z |
      | 2026-11-19T11:04    | 2026-11-19T11:04:06 | 2026-11-19T11:04:00Z           | 2026-11-19T11:04:06Z           |

  Scenario: Reject a bookmark containing only picker inputs
    When I open a Logs link with UTC picker fields alone
    Then the full Logs view should reject the dates with HTTP 400

  Scenario Outline: Read logs in the preferred browser language
    Given acknowledged searchable logs
    When I investigate them in a "<layout>" view with browser languages "<preferences>"
    And I load activity for that search with browser languages "<preferences>"
    Then I should see the "<layout>" log view in "<language>"
    And the activity chart should use "<language>"
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
    And the results should keep the exact range and the link should preserve the submitted filters

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
    Then I should see a short empty state with an option to clear all filters
    And the "<layout>" view should show warnings in the same time range for the selected service
    And clearing all filters should keep the same time range

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
    When I choose the last 15 minutes and follow Next page without htmx
    And I reload the paged search link after a matching log arrives
    Then the full pages should show "same-time first" followed by "first" in the same filtered search
    And reloading should show the new matching log in a refreshed 15-minute window

  Scenario: Find related logs from a later page
    Given acknowledged logs with related requests of different severities and messages
    When I find related logs from a later page of an active message and severity search
    Then I should see the matching trace with the same time range and filters

  Scenario: Reload related logs after opening them from a recent search
    Given acknowledged recent logs with matching requests and other messages, severities and traces
    When I find related logs from a 15-minute search
    Then the related search should keep the exact interval and reload with the default window

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
    Then the failed query should show that log storage is unavailable in German
    And the later query should show the selected service's log messages and exact event times

  Scenario: An expired query shows a timeout without displaying a partial result
    Given acknowledged searchable logs
    When my Spanish log query exhausts its budget
    Then I should see a Spanish log timeout
