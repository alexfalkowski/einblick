# 🔎 Recent-log queries

[← Back to README](../README.md)

## 🖥️ Investigate recent logs in the browser

Open `http://localhost:11000/logs` with the development configuration.
The page opens on local logs over the configured maximum range ending now.
Choose **15 min**, **1 hour**, **24 hours**, **3 days**, or **7 days** to run a
search ending now with the filters in the form. The page shows the presets that
fit the configured search limit and highlights the applied duration. A limit
shorter than 15 minutes offers **Recent**, which uses the configured duration.
Enter the exact service name in the sidebar and narrow the results with
**Search messages**, a hexadecimal trace ID, or severity. The severity choices
are Debug, Info, Warn, Error, and Fatal. Each matches its exact level. **All severities**
includes any other levels in the stored data. An empty service filter includes
logs from all services, including records without a service name.

Choose **Search** or press Enter to apply filter edits to the current time
window. Matching text is highlighted in the message preview. Clear the message
search with **×** or **Clear search** in the empty state to rerun with the same
time window and other filters.

Select a row or focus its message and press Enter to open **Log details**.
The inspector slides over the results from the right and fills the screen on
narrow displays. Use the close button or press Escape to return to the selected
message. On wide screens, clicking the dimmed backdrop also closes the inspector.

The inspector shows the full message, service, environment and time to receipt
when available. HTTP and gRPC request logs also show the reported status and
request duration. Expand **Attributes** for individual values and nested
lists, **Source** for resource and instrumentation details, or
**Timing and IDs** for exact timestamps and copyable trace and span IDs.
Use the query API to retrieve the original typed OTLP fields.

Follow **Next page** to continue the same query. The address bar captures the
submitted absolute range, filters and page position. Use Back to return to the
previous query. **Reset** clears the filters and opens the latest local
window. The table shows event time in UTC to the second. When the producer
omits event time, the summary labels the observation or receipt time used in its
place. Shared links retain the exact bounds, including fractional seconds. A
duration outside the presets is marked **Current range**. Presets replace the
UTC date and time pickers. Existing absolute-range bookmarks still open within
the configured query limit. To construct a custom interval, supply both
`start_time` and `end_time` as RFC 3339 timestamps in the `/logs` URL or use
the [query API](#-query-recent-logs-through-the-api).
Open **Timing and IDs** on a log and choose **Find related logs** to search for
its trace in the current time range with the other filters still applied. You
can also paste an ID from another tool into **Trace ID**. In-place updates use
htmx from jsDelivr. When the browser cannot load it, searches and pagination
open full pages.

The browser negotiates English, German or Spanish with English fallback.
If there are no matches, select a longer preset or clear a filter. If a saved
search link fails, choose **Open Logs** to start a fresh search.
If the shared HTTP deadline expires first, in-place queries show
a timeout and direct navigation can return an empty HTTP 504 response. When
offered after a network or gateway error, **Try again** sends the failed search
with the same inputs. The page reads local storage and uses the same query
bounds and ordering as the API.
Anyone who can reach the route through the HTTP listener can query it without
a site login.

## 🔌 Query recent logs through the API

Use `einblick.v1.Service/ListLogs` over gRPC or
`POST /einblick.v1.Service/ListLogs` on the HTTP listener. Both use the
[versioned protobuf contract](../api/einblick/v1/service.proto). Queries read
the local DuckDB database and accept the fixed filters below. Archived reads
are planned.

With the development configuration:

```sh
curl --fail http://localhost:11000/einblick.v1.Service/ListLogs \
  -H 'Content-Type: application/pbjson' \
  -H 'Accept: application/pbjson' \
  --data '{"startTime":"2026-11-19T11:04:05.123456789Z","endTime":"2026-11-19T11:04:05.123456799Z","service":"e01-client","pageSize":20}'
```

These absolute timestamp bounds match the synthetic log fixture; send logs
first or expect an empty page. Use `application/pbjson` for canonical protobuf
JSON, including RFC 3339 Timestamp strings. The shared HTTP RPC transport owns
content negotiation. Generated gRPC clients call `ListLogs` on port `12000`.

## 🕒 Time and filter scope

`start_time` and `end_time` are required protobuf Timestamps. In protobuf JSON
they are RFC 3339 strings with an explicit
`Z` or numeric timezone offset and up to nanosecond precision, following
[AIP-142](https://google.aip.dev/142). The interval includes `start_time` and
excludes `end_time`. Equivalent timezone representations select the same window
and can continue the same query. Returned times are normalized to UTC.

Query time follows the stored event-time policy: Timestamp, then
ObservedTimestamp, then server receipt time. Original timestamps remain in each
record. Bounds must fit the stored unsigned OTLP time range, from the Unix
epoch through the exclusive upper boundary `2554-07-21T23:34:33.709551616Z`.
The configured maximum range still applies. API clients supply both bounds.

All supplied filters must match:

| Parameter | Meaning |
| --- | --- |
| `service` | Exact string `service.name` resource attribute; omitted/empty selects all services. |
| `severity` | Exact OTLP severity suffix, such as `INFO`, `ERROR`, `WARN2` or `UNSPECIFIED`; omitted/empty selects all severities. This is not a minimum threshold. |
| `text` | Case-sensitive literal substring of string bodies only. Attributes, resource/scope fields and non-string bodies are outside text-search scope. SQL and wildcard characters remain literal. |
| `trace_id` | Exactly 32 hexadecimal characters, either case. It matches the record's trace ID; omitted/empty selects correlated and uncorrelated records. |
| `page_size` | Positive page size up to the configured maximum. Omitted or zero uses the maximum. |
| `page_token` | Opaque continuation token returned by the previous page. Keep all other parameters fixed, including the effective page size. |

## 📄 Results and pagination

The response contains `meta`, `logs` and `next_page_token`. `meta` carries shared
request metadata such as `request_id` and `user_agent`. Each log includes a local
`id`, protobuf `event_time` and `receive_time` Timestamps, and typed OTLP
`resource`, `scope` and `record` messages.

Canonical protobuf JSON uses camelCase field names: `startTime`, `endTime`,
`traceId`, `pageSize`, `pageToken`, `nextPageToken`, `eventTime` and `receiveTime`.
The decoder also accepts the proto's snake_case names shown in the filter table.
Response IDs and other 64-bit integers are decimal strings; bytes use base64.
Timestamps are UTC RFC 3339 strings preserving nanoseconds. These messages retain
the complete original typed content.
Trace/span IDs inside the original record also use protobuf JSON's base64 form;
the query filter accepts hexadecimal IDs.

Results sort by event time descending, then local ID descending. Duplicate
exports remain separate records. Each page reads the committed records visible
to that query. Continuation pages select records strictly after the last result
in that descending order, using its event time and ID.

Newly committed records behind the cursor can appear on later pages. Records
ahead of the cursor, including equal-time arrivals with higher IDs, require a
fresh query. Existing records do not repeat across pages. Pagination does not
freeze membership or coordinate with ingestion.

Copy the returned token to `page_token` and repeat the same query. An empty token
means exhaustion. Token size is independent of filter length. No logs and an
empty token means no matches. Protobuf JSON omits default-valued fields, so
`logs` and `nextPageToken` can be absent; generated
clients expose an empty collection and empty string respectively.
There is no total-count query. Tokens survive service restarts and have no
time-based expiry while all local source rows remain retained. They are
continuation data, not credentials; clients must treat them as opaque.
Archive/eviction support must define continued source ownership or explicit
expiry before removing local rows.

## ⏱️ Bounds and failures

Required [query configuration](configuration.md#-recent-log-queries) limits page
size, selected range, timeout and active queries. The query timeout covers queue
waits and SQL work together. Cancellation propagates to
DuckDB; the service returns no partial page on failure. The HTTP request timeout
can end a query earlier, so align it with the desired query budget.

| Outcome | HTTP result | gRPC result |
| --- | --- | --- |
| No matches | `200`, empty page. | `OK`, empty page. |
| Invalid bounds, filters, page size or token; changed pagination parameters | `400`. | `InvalidArgument`. |
| Cancelled request | `499` when the connection can still carry a response. | `Canceled`. |
| Deadline exceeded | `504`. | `DeadlineExceeded`. |
| Local query/storage failure, including native resource exhaustion | `503`. | `Unavailable`. |

Errors use go-service's safe error responses. A disconnected client may receive
no response. No partial coverage or successful empty result is substituted for
a failed database read. `component=logs` diagnostics report query outcomes;
successful-query diagnostics include returned count and duration.
