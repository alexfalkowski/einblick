@archive @publication @archive_history
Feature: Read acknowledged logs across local storage and the archive
  Operators can continue a log investigation as published batches leave local storage.

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

  Scenario: Keep a batch with a recently received member
    Given acknowledged logs are ready to archive
    When the worker evicts eligible batches and the earlier batch has a recent receipt
    Then eviction should reclaim the later batch and retain the earlier batch locally

  Scenario: Read shared context after a sibling batch is evicted
    Given an acknowledged export was split into batches that share resource and scope context
    When one batch is evicted while the other is waiting to publish
    Then all original logs and their typed context should remain queryable

  Scenario: Discover logs on a fresh database volume
    Given acknowledged logs are ready to archive
    When the archive is published and the client searches from a fresh database volume
    Then the archive should supply the complete matching logs
    And the fresh instance should leave the original archive objects unchanged

  Scenario: Page through matching IDs from different volumes across eviction
    Given acknowledged logs are ready to archive
    When a fresh volume accepts the same logs and evicts them after the client reads the first page
    Then pagination should include both copies of every matching log

  Scenario: Report unavailable history distinctly from an empty page
    Given acknowledged logs are ready to archive
    When the archive is published and the client searches during an object store outage
    Then the log query should report unavailable history

  Scenario: Search archived logs after a transient listing failure
    Given acknowledged logs are ready to archive
    When the archive is published and the client searches while the object store briefly fails to list archives
    Then the archive should supply the complete matching logs

  Scenario: Publish logs while archive listings are unavailable
    Given log archival is configured for a disposable object store
    When the service accepts logs after a listing failure opens the search circuit breaker
    Then the log query should report unavailable history
    And the object store should contain one Parquet batch with the accepted logs
    And the published batch should be recorded and its staging file reclaimed

  Scenario: Report unavailable history when an evicted archive object is missing
    Given acknowledged logs are ready to archive
    When the client searches the same volume after one matching evicted archive object disappears
    Then the log query should report unavailable history
    And the search should have returned both copies of the matching logs before the loss

  Scenario: Retry after cancelling an archive query
    Given acknowledged logs are ready to archive
    When the client cancels an active archive query, searches while it drains, and retries
    Then the cancelled archive query should return gRPC cancelled
    And the queued search should end without listing the archive
    And the archive should supply the complete matching logs
