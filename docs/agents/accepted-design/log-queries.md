# Accepted design for log queries

These entries are part of the [accepted-design index](../accepted-design.md).

## Initial browser search window

The Logs page opens on the last hour, capped by the configured query limit.
This narrows archive discovery on initial navigation. Longer searches are
available through the time presets and absolute links within the configured limit.
[Log queries](../../queries.md#-investigate-logs-in-the-browser)

## Search scope

Log searches use an explicit scope. The response reports which sources the
search covered, including for empty results.
[ListLogs protobuf contract](../../../api/einblick/v1/service.proto)

## Search admission by scope

Apply `queries.concurrency` independently to current-volume and archive-inclusive
searches. A stalled native archive read keeps its archive slot until cleanup
finishes. Local-only searches use the current-volume slots.
[Query configuration](../../configuration.md#-recent-log-queries)

## Response work after repository admission

The query repository releases admission when it returns a page. The API and
MVC callers then convert, encode or render that page. The result limit counts
rows, so repeated resource and scope data can still produce a large response.

The owner deferred response-byte budgeting and extending admission through
response completion. Treat these as unresolved resource-policy decisions when
reviewing or changing the query path.
[Query review](https://github.com/alexfalkowski/einblick/pull/30#pullrequestreview-5990925769) · [MVC follow-up](https://github.com/alexfalkowski/einblick/pull/32#pullrequestreview-5997163742)
