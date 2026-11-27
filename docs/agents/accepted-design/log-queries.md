# Accepted design for log queries

These entries are part of the [accepted-design index](../accepted-design.md).

## Browser time selection and refresh

The Logs page opens on the last hour, capped by the configured query limit.
For rolling selections, the address bar keeps the duration so reloads start
a fresh search up to now, including after paging. Pagination and investigation
actions can use the exact
applied bounds. Apply the shared controls on every time-filtered view.
[Time controls](../../requirements.md#time-controls) ·
[Log queries](../../queries.md#-investigate-logs-in-the-browser)

Reuse the [browser time selection package](../../../internal/site/timerange) for
presets, exact bounds and reload durations. The
[Logs query package](../../../internal/site/logs/query) binds log-specific filters
and builds continuation links. The repository validates the cursor against the
executed query.

When adding a custom range, reveal its date-and-time fields below the
preset buttons. Size both inputs to fill the available form width and give
them accessible names instead of visible labels. Keep **Search** beside
**Reset** so one submit action applies the time range and other filters.

Custom searches and range selections from the activity chart retain their
absolute URL bounds on reload. The Custom form sends UTC picker values with
its exact applied bounds. Shareable fixed ranges use RFC 3339 bounds. Positive
R2 retention bounds selectable log event dates in the browser. The repository
determines archive coverage by object age and availability.
[Browser log queries](../../queries.md#-investigate-logs-in-the-browser)

Load the activity chart and total automatically once search results are
visible. Put the total above the results table. Show the bucket size beside
the chart title and mark UTC on the last time label. Use a tooltip for
bucket details on hover and the selected interval while dragging. When
timed refresh moves the results ahead, show the chart's end time in its
header.

## Search sources

The query API and the Logs page choose sources from the time bounds. Ranges
covered by the current database volume use local query capacity. Searches
that need unavailable archive history return an error in both interfaces.
[ListLogs protobuf contract](../../../api/einblick/v1/service.proto)

## Search admission by source

Apply `queries.concurrency` independently to current-volume and archive-inclusive
searches. A stalled native archive read keeps its archive slot until cleanup
finishes. Local-only searches use the current-volume slots.
Automatic activity takes an archive slot only when a slot remains available
for a log page. If there is no spare capacity, activity reports unavailable.
[Query configuration](../../configuration.md#-recent-log-queries)

## Response work after repository admission

The query repository releases admission when it returns a page. The API and
MVC callers then convert, encode or render that page. The result limit counts
rows, so repeated resource and scope data can still produce a large response.

The owner deferred response-byte budgeting and extending admission through
response completion. Treat these as unresolved resource-policy decisions when
reviewing or changing the query path.
[Query review](https://github.com/alexfalkowski/einblick/pull/30#pullrequestreview-5990925769) · [MVC follow-up](https://github.com/alexfalkowski/einblick/pull/32#pullrequestreview-5997163742)
