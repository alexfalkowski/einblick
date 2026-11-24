@queries
Feature: Query recent logs
  Clients investigate acknowledged local logs within a fixed absolute window.
  Pages continue after the last returned event time and ID while further logs arrive.

  Background:
    Given acknowledged searchable logs

  Scenario: Query complete records in the selected service and absolute window
    When the client queries recent logs
    Then the query should return complete matching logs latest first

  Scenario: Query the same complete records through the generated gRPC client
    When the client queries recent logs using gRPC
    Then the gRPC query should return complete matching logs latest first

  Scenario Outline: Query acknowledged logs across services without a service selection
    Given acknowledged labelled and unlabelled logs in an isolated time window
    When the client queries logs with the service filter "<selection>"
    Then the query should return complete matching logs latest first

    Examples:
      | selection |
      | omitted   |
      | empty     |

  Scenario: Continue an HTTP query using the generated gRPC client
    Given the client has read the first recent-log page
    When the client continues the HTTP log query using gRPC
    Then pagination should return each original matching log once in order

  Scenario: Continue a gRPC query with a large accepted text filter
    Given two separately acknowledged logs matching a 500 KiB text filter
    When the client reads the matching logs in single-record gRPC pages
    Then the large-filter query should return both complete records across exhausted pages

  Scenario Outline: gRPC clients receive invalid argument for unsupported queries
    When the client queries recent logs using gRPC with <parameters>
    Then the log query should fail safely with gRPC 3

    Examples:
      | parameters                                    |
      | {"start_time":null}                           |
      | {"end_time":null}                             |
      | {"end_time":"2026-11-19T11:04:05.123456789Z"} |
      | {"page_size":101}                             |
      | {"severity":"unknown"}                        |
      | {"page_token":"invalid"}                      |

  Scenario: A gRPC deadline returns no partial page
    When a gRPC log query exhausts its configured budget
    Then the log query should fail safely with gRPC 4

  Scenario Outline: Filter logs without interpreting user text as SQL or patterns
    When the client queries recent logs with <parameters>
    Then the log query should return record positions "<positions>"

    Examples:
      | parameters                                                                                            | positions   |
      | {"severity":"ERROR"}                                                                                  | 3           |
      | {"severity":"UNSPECIFIED"}                                                                            | 4           |
      | {"trace_id":"0102030405060708090a0b0c0d0e0f10"}                                                       | 2           |
      | {"text":"%_ ' OR 1=1 --"}                                                                             | 5           |
      | {"text":"%"}                                                                                          | 5           |
      | {"text":"_"}                                                                                          | 5           |
      | {"severity":"INFO","text":"same-time"}                                                                | 2           |
      | {"start_time":"2026-11-19T11:04:05.123456790Z","end_time":"2026-11-19T11:04:05.123456791Z"}           | 3,2         |
      | {"end_time":"2026-11-26T11:04:05.123456789Z"}                                                         | 6,5,4,3,2,1 |
      | {"start_time":"2026-11-19T12:04:05.123456790+01:00","end_time":"2026-11-19T12:04:05.123456791+01:00"} | 3,2         |

  Scenario Outline: Return a successful empty page when no logs match
    When the client queries recent logs with <parameters>
    Then the log query should return no matches

    Examples:
      | parameters                  |
      | {"service":"missing"}       |
      | {"text":"LITERAL"}          |
      | {"text":"9007199254740993"} |
      | {"severity":"FATAL"}        |

  Scenario: New arrivals behind the cursor enter later pages without repeating records
    Given the client has read the first recent-log page
    When newer, equal-time and late logs arrive while the client reads the remaining pages
    Then pagination should include arrivals behind the cursor without repeating records
    And a fresh log query should include the newly acknowledged records

  Scenario: The configured limit applies to default-sized pages
    Given more acknowledged matching logs than fit in the configured page limit
    When the client reads logs using the default page size
    Then the configured page limit should bound complete results without losing records

  Scenario Outline: Continue reading acknowledged logs after a restart
    Given the client has read the first recent-log page
    When the client continues the recent-log query after a "<mode>" restart
    Then pagination should return each original matching log once in order

    Examples:
      | mode        |
      | graceful    |
      | interrupted |

  Scenario Outline: Reject unsupported or unbounded queries
    When the client queries recent logs with <parameters>
    Then the log query should fail safely with HTTP 400

    Examples:
      | parameters                                      |
      | {"start_time":""}                               |
      | {"start_time":"1969-12-31T23:59:59.999999999Z"} |
      | {"start_time":"not-a-time"}                     |
      | {"start_time":"1795086245123456789"}            |
      | {"start_time":"2026-11-19T11:04:05"}            |
      | {"end_time":"2026-11-19T11:04:05.123456789Z"}   |
      | {"end_time":"2554-07-21T23:34:33.709551617Z"}   |
      | {"end_time":"2026-11-26T11:04:05.123456790Z"}   |
      | {"page_size":101}                               |
      | {"page_size":-1}                                |
      | {"page_size":"invalid"}                         |
      | {"severity":"unknown"}                          |
      | {"trace_id":"xyz"}                              |
      | {"trace_id":"00"}                               |
      | {"trace_id":"0102030405060708090a0b0c0d0e0f1g"} |
      | {"page_token":"invalid"}                        |

  Scenario Outline: Reject unsigned timestamp boundaries within the permitted range
    When the client queries recent logs with <parameters>
    Then the log query should fail safely with HTTP 400

    Examples:
      | parameters                                                                                  |
      | {"start_time":"1969-12-31T23:59:59.999999999Z","end_time":"1970-01-01T00:00:00.000000001Z"} |
      | {"start_time":"2554-07-21T23:34:33.709551615Z","end_time":"2554-07-21T23:34:33.709551617Z"} |

  Scenario Outline: Reject changes to a paginated query
    Given the client has read the first recent-log page
    When the client changes the paginated query with <parameters>
    Then the log query should fail safely with HTTP 400

    Examples:
      | parameters                                      |
      | {"service":"different"}                         |
      | {"severity":"INFO"}                             |
      | {"text":"failed"}                               |
      | {"trace_id":"0102030405060708090a0b0c0d0e0f10"} |
      | {"page_size":3}                                 |
      | {"start_time":"2026-11-19T11:04:05.123456790Z"} |
      | {"end_time":"2026-11-19T11:04:05.123456798Z"}   |

  Scenario: Pagination accepts equivalent absolute times in another timezone
    Given the client has read the first recent-log page
    When the client continues the query with timezone-equivalent bounds
    Then pagination should return each original matching log once in order

  Scenario: Query nanoseconds at the full unsigned boundary
    When the client queries acknowledged logs at the unsigned timestamp boundary
    Then the unsigned log query should return both exact records across exhausted pages

  Scenario: Query logs using receipt time when both original times are absent
    When the client queries acknowledged logs without event or observed timestamps
    Then the query should return complete matching logs latest first

  Scenario: An already expired query budget returns no partial page
    When a recent-log query exhausts its configured budget and the client retries normally
    Then the expired log query should time out without a partial page
    And the query should return complete matching logs latest first

  @native_query_work
  Scenario: Native work stops at the query deadline and releases its slot
    Given a log investigation with substantial native query work
    When a long-running native log query times out and the client continues its earlier query
    Then the expired log query should time out without a partial page
    And concurrent log queries should respect the single-query work limit
    And pagination should return each original matching log once in order

  Scenario: Unavailable storage is distinguishable from an empty result
    When the client queries temporarily unavailable local logs
    Then the log query should fail safely with HTTP 503

  Scenario: gRPC clients distinguish unavailable storage from an empty result
    When the client queries temporarily unavailable local logs using gRPC
    Then the log query should fail safely with gRPC 14

  @native_query_work
  Scenario: Caller cancellation releases native work for the next investigation
    Given the client has read the first recent-log page
    And a log investigation with substantial native query work
    When the client cancels an active native log query and continues its earlier query
    Then the cancelled log query should release native work promptly
    And pagination should return each original matching log once in order
