@archive
Feature: Stage closed local log archives
  Operators can recover complete Parquet batches on the local staging volume.
  Accepted logs remain available on the persistent database volume.

  Scenario: Export original log content to its UTC event day
    Given typed logs spanning UTC midnight and using both timestamp fallbacks
    When the service stages the acknowledged logs
    Then the Parquet files should preserve the complete log export and exact timestamps
    And each Parquet file should contain records for its UTC event day
    And each Parquet file should match its durable batch
    And the acknowledged logs should remain in DuckDB

  Scenario: Stage an accepted row larger than the batch target
    Given an accepted-size log body larger than the Parquet batch target
    When the service stages that log export
    Then the larger row should have its own batch and retain its original content

  Scenario Outline: Split a same-day export that exceeds the batch target
    Given three same-day logs with large "<content>" that fit the batch target only two at a time
    When the service stages that log export
    Then one Parquet batch should contain two logs and the other should contain one
    And each Parquet file should match its durable batch

    Examples:
      | content        |
      | bodies         |
      | shared context |

  Scenario: Restrict a previously shared export directory to the service user
    Given an archive workspace with a publicly accessible export directory
    When the service starts with local archival enabled
    Then the export directory should be accessible only to the service user

  Scenario: Export late logs to an already staged UTC day
    Given a log export for an earlier UTC day
    When the logs arrive twice with the same worker running and the first batch already staged
    Then the UTC day should have two distinct complete batches
    And the first completed Parquet file should be unchanged

  Scenario: Initialize an empty archive workspace
    Given an empty archive workspace
    When the service starts with local archival enabled
    Then the export directory should be accessible only to the service user

  Scenario: Refuse to start without the configured archive workspace
    Given the configured archive workspace is missing
    When the service attempts to start with local archival enabled
    Then startup should fail without creating an export directory

  Scenario: Refuse to start with an unwritable archive workspace
    Given an empty archive workspace without write access
    When the service attempts to start with local archival enabled
    Then startup should fail without creating an export directory

  Scenario: Retry publication after permissions are restored
    Given a log export for an earlier UTC day
    When the service accepts that export while the destination day is unwritable and write access returns
    Then the failed publication should leave no temporary or completed files
    And the original export should be staged without another request
    And the retry should complete the original batch
    And each Parquet file should match its durable batch

  Scenario: Pause staging when the workspace is replaced
    Given a log export for an earlier UTC day
    When the service accepts that export with a replacement workspace and the original workspace returns
    Then the replacement workspace should receive no archive files
    And the original export should be staged without another request
    And each Parquet file should match its durable batch

  Scenario: Accept logs while recovery cannot read a staged file
    Given an acknowledged log export staged in Parquet
    When the service restarts with an unreadable staged file and receives another log export
    Then the service should defer further staging until read access is restored
    And the newly accepted logs should be queryable during recovery
    And the UTC day should have two distinct complete batches
    And the first completed Parquet file should be unchanged

  Scenario Outline: Recover retained batches after a staging failure
    Given an acknowledged export with "<state>" staging
    When the service restarts with writable staging
    Then the original batch membership and content identity should be preserved
    And only a verified complete Parquet file should remain for the batch
    And the acknowledged logs should remain in DuckDB
    And each Parquet file should match its durable batch

    Examples:
      | state    |
      | partial  |
      | unmarked |
      | corrupt  |
      | missing  |

  Scenario: Resume an interrupted batch before staging new arrivals
    Given an acknowledged export with "partial" staging
    When another export is accepted and the archive worker restarts
    Then the interrupted batch should complete before the new batch
    And the UTC day should have two distinct complete batches
    And each Parquet file should match its durable batch
