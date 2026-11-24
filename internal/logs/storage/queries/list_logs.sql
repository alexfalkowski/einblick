SELECT id, event_timestamp_ns::VARCHAR, received_timestamp_ns::VARCHAR, resource, scope, record, source
FROM selected_logs
WHERE event_timestamp_ns BETWEEN ?::UBIGINT AND ?::UBIGINT
  AND (event_timestamp_ns < ?::HUGEINT OR (event_timestamp_ns = ?::HUGEINT
       AND (id < ? OR (id = ? AND source < ?))))
  AND (? = '' OR EXISTS (
      SELECT 1 FROM json_each(resource, '$.resource.attributes') a
      WHERE json_extract_string(a.value, '$.key') = 'service.name'
        AND json_extract_string(a.value, '$.value.stringValue') = ?))
  AND (? = '' OR coalesce(json_extract_string(record, '$.severityNumber'), 'SEVERITY_NUMBER_UNSPECIFIED') = ?)
  AND (? = '' OR contains(json_extract_string(record, '$.body.stringValue'), ?))
  AND (? = '' OR json_extract_string(record, '$.traceId') = ?)
ORDER BY event_timestamp_ns DESC, id DESC, source DESC
LIMIT ?;
