@archive @publication @archive_history
Feature: Read acknowledged logs across local storage and the archive
  Operators can continue a log investigation as published batches leave local storage.

  Scenario: Continue to an older day when newer archives become unreadable
    Given acknowledged logs span the daily archive cutoff and include a late arrival
    When the worker archives the late arrival and the newer archives become unreadable after the first page
    Then a paginated search should include every acknowledged log once
    And the late arrival should remain local until it can be archived
    And the first page should find the archived days with one listing request

  Scenario: Publish and evict a day across multiple Parquet row groups
    Given 24 acknowledged logs for a closed day share a large resource
    When the worker archives the day with local eviction enabled
    Then one remote Parquet file should contain every acknowledged log for the day
    And the archive file should use bounded Parquet row groups
    And eviction should reclaim the local batch and its unused context

  Scenario: Continue a saved page across publication and eviction
    Given a client has the first page of acknowledged logs before archival
    When the client continues the search during publication overlap and after local eviction
    Then the client should read each matching typed log once in the same order
    And eviction should reclaim the local batch and its unused context

  Scenario: Keep an active page complete during source eviction
    Given acknowledged logs are ready to archive
    When another batch is evicted while the client is reading archived logs
    Then the active page should contain both batches exactly once

  Scenario: Keep an active page complete when publication follows archive listing
    Given acknowledged logs are ready to archive
    When the client receives an archive listing captured before another batch was published and evicted
    Then the active page should contain both batches exactly once

  Scenario Outline: Continue eviction when an earlier archive object fails verification
    Given acknowledged logs are ready to archive
    When the first published archive object is "<fault>" before local eviction and the client searches afterward
    Then eviction should reclaim the later batch and retain the earlier batch locally
    And the search should return both batches exactly once

    Examples:
      | fault                             |
      | missing                           |
      | checksum changed                  |
      | contents changed without checksum |

  Scenario: Read shared context after a sibling batch is evicted
    Given an acknowledged export was split into batches that share resource and scope context
    When one batch is evicted while the other is waiting to publish
    Then all original logs and their typed context should remain queryable

  Scenario: Discover logs on a fresh database volume
    Given acknowledged logs are ready to archive
    When the archive is published and the client searches from a fresh database volume
    Then the archive should supply the complete matching logs
    And the Logs page should continue to the next archived log
    And the fresh instance should leave the original archive objects unchanged

  Scenario: Page through matching IDs from different volumes across eviction
    Given acknowledged logs are ready to archive
    When a fresh volume accepts the same logs and evicts them after the client reads the first page
    Then pagination should include both copies of every matching log

  @archive_history_availability
  Scenario: Report unavailable history distinctly from an empty page
    Given acknowledged logs are ready to archive
    When the archive is published and the client searches during an object store outage
    Then the log query should report unavailable history

  @archive_history_availability
  Scenario: Show unavailable history after reopening an archived database without R2
    Given acknowledged logs are ready to archive
    When the worker evicts the archived logs and the operator reopens the database without R2
    Then the Logs page should report that log storage is unavailable
    And the API should report unavailable history for the older range
    And the default recent search should still succeed

  @archive_history_availability
  Scenario: Retry an older search after an archive outage
    Given acknowledged logs are ready to archive
    When the operator searches during an archive outage and retries after recovery
    Then the Logs page should report that log storage is unavailable
    And the retried search should return the matching logs
    And the API should report unavailable history for the older range
    And publication recovery should drain the visible log backlog

  @archive_history_availability
  Scenario: Search the last 24 hours during an archive outage
    Given acknowledged recent logs on the server
    When the operator searches the last 24 hours during an archive outage
    Then the Logs page should show the recent logs
    And the API should return each matching recent log across pages

  @archive_history_availability @native_query_work
  Scenario: Keep metrics available when slow backlog reads time out
    Given acknowledged logs are ready to archive
    And backlog reads can be slowed within the running service
    When a slow backlog read times out after the operator has seen pending records
    Then a metrics scrape during the first slow read should report the previous backlog count
    And the metrics endpoint should withdraw the previous backlog sample after the timeout
    And the sampler should rest after a slow read

  @archive_history_availability
  Scenario: Keep available history readable when an older archive expires
    Given acknowledged logs are ready to archive
    When archive objects disappear and the operator changes the query retention setting
    Then the search should return the remaining history
    And disabling query expiration should require the missing object again
    And a missing object still within retention should report unavailable history

  @archive_history_availability
  Scenario: Report unavailable history when a follow-up listing fails
    Given acknowledged logs are ready to archive
    When an eligible archive object disappears and the follow-up listing fails
    Then the active search should report unavailable history

  @archive_history_availability
  Scenario: Preserve coverage when a younger object disappears during expiration retry
    Given acknowledged logs are ready to archive
    When a fresh volume searches while an expired object and a younger object disappear
    Then the search should report unavailable history after refreshing the archive listing

  @archive_history_availability
  Scenario: Search archived logs after a transient listing failure
    Given acknowledged logs are ready to archive
    When the archive is published and the client searches while the object store briefly fails to list archives
    Then the archive should supply the complete matching logs

  @archive_history_availability
  Scenario: Use the listing timestamp when the stored object age is unknown
    Given acknowledged logs are ready to archive
    When an older evicted batch expires during an archive search and the operator searches again
    Then the active search should return the remaining history
    And the later search should report unavailable history when the missing object's age is unknown

  @archive_history_availability
  Scenario: Publish logs while archive listings are unavailable
    Given log archival is configured for a disposable object store
    When the worker publishes ready logs after a listing failure opens the search circuit breaker
    Then the log query should report unavailable history
    And the object store should contain one Parquet batch with the accepted logs
    And the published batch should be recorded and its staging file reclaimed

  @archive_history_availability
  Scenario: Report unavailable history when an evicted archive object is missing
    Given acknowledged logs are ready to archive
    When the client searches the same volume after one matching evicted archive object disappears
    Then the log query should report unavailable history
    And the search should have returned both copies of the matching logs before the loss

  @archive_history_availability
  Scenario: Retry after cancelling an archive query
    Given acknowledged logs are ready to archive
    When the client cancels an active archive query, searches while it drains, and retries
    Then the cancelled archive query should return gRPC cancelled
    And the recent search should return its records while the archive read is still held
    And the queued search should end without listing the archive
    And the archive should supply the complete matching logs
