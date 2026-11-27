# Accepted design for log queries

These entries are part of the [accepted-design index](../accepted-design.md).

## Browser appearance

Use the existing light palette by default. Apply the dark palette through CSS
`prefers-color-scheme` so the open page follows changes to the browser’s
appearance preference. Set `color-scheme` so native controls match.
[Frontend requirements](../../requirements.md#86-embedded-frontend)

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
absolute URL bounds on reload. Use the browser's time zone for displayed
times and Custom inputs. Show a pill with the time-zone city beside **Custom**
while the dates are visible. Use the full time zone in the accessible names
of the date inputs. Show full timestamp precision in the browser's time zone
in **Timing and IDs** and keep the underlying timestamps in UTC.
Convert Custom values to UTC on submit and keep the exact applied instant when
the field is unchanged. Reject skipped local times and use the earlier
occurrence for newly entered repeated times. Shareable fixed ranges use RFC
3339 bounds. Positive
R2 retention bounds selectable log event dates in the browser. The repository
determines archive coverage by object age and availability.
On an in-page search with an expired start date, show the current cutoff under
that field.
[Browser log queries](../../queries.md#-investigate-logs-in-the-browser)

Load the activity chart and total automatically on page entry, search and
timed refresh. Page changes reuse the existing total for the applied query.
Put the total above the results table. Show the bucket size beside
the chart title and reuse the Custom time-zone label on the last time label.
Use the same time-zone label with the timestamp-specific UTC offset in chart
and table tooltips and in **Timing and IDs**. Show the zone once for ranges
whose endpoints have the same offset. Show bucket details on hover and the
selected interval while dragging. Round chart tooltip times to the nearest
minute for minute-sized or larger buckets and to the nearest second for finer
buckets, respecting UTC offset changes.
Searches from the chart use exact bounds. Show the displayed chart's end time
in its header. Keep the current table, chart and count visible during a fast
update and replace them together. If activity is slow, show the new table and
**Updating count…**. Replace that message with the total or **Match count
unavailable** when the activity request finishes.
Offer **Clear filters** in the filtered empty state and keep the applied range.

Keep the chart, match count and search status areas in the layout while their
contents update. Keep the last chart visible while activity loads for a
different search. Mark it as **Previous search** if activity is slow or fails.
Use the existing slow-search delay for the activity wait. Keep
Search and Auto-refresh available, give the latest submitted search priority
and skip timed refreshes while a result request is active. Turning Auto-refresh
off discards any timed result waiting to be displayed. Keep the last successful
results visible when a search fails. Keep the failure banner to the error reason
and **Try again**, which retries the failed request.

## Search sources

The query API and the Logs page choose sources from the time bounds. Ranges
covered by the current database volume use local query capacity. Searches
that need unavailable archive history return an error in both interfaces.
[ListLogs protobuf contract](../../../api/einblick/v1/service.proto)

## Search admission by source

Allow one active current-volume search and two active archive-inclusive searches
with independent admission. A stalled native archive read keeps its archive
slot until cleanup finishes.
Automatic activity takes an archive slot only when a slot remains available
for a log page. If there is no spare capacity, activity reports unavailable.
Show a retry action for temporary archive contention and chart timeouts.
[Query configuration](../../configuration.md#-recent-log-queries)

## Response work after repository admission

The query repository releases admission when it returns a page. The API and
MVC callers then convert, encode or render that page. The result limit counts
rows, so repeated resource and scope data can still produce a large response.

The owner deferred response-byte budgeting and extending admission through
response completion. Treat these as unresolved resource-policy decisions when
reviewing or changing the query path.
[Query review](https://github.com/alexfalkowski/einblick/pull/30#pullrequestreview-5990925769) · [MVC follow-up](https://github.com/alexfalkowski/einblick/pull/32#pullrequestreview-5997163742)
