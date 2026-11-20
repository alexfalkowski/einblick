SELECT l.id, l.event_timestamp_ns::VARCHAR, l.received_timestamp_ns::VARCHAR,
       r.content::VARCHAR, s.content::VARCHAR, l.content::VARCHAR
FROM logs l
JOIN log_scopes s ON s.id = l.scope_id
JOIN log_resources r ON r.id = s.resource_id
WHERE l.event_timestamp_ns >= ?::HUGEINT AND l.event_timestamp_ns < ?::HUGEINT
  AND (l.event_timestamp_ns < ?::HUGEINT OR (l.event_timestamp_ns = ?::HUGEINT AND l.id < ?))
  AND (? = '' OR EXISTS (
      SELECT 1 FROM json_each(r.content, '$.resource.attributes') a
      WHERE json_extract_string(a.value, '$.key') = 'service.name'
        AND json_extract_string(a.value, '$.value.stringValue') = ?))
  AND (? = '' OR coalesce(json_extract_string(l.content, '$.severityNumber'), 'SEVERITY_NUMBER_UNSPECIFIED') = ?)
  AND (? = '' OR contains(json_extract_string(l.content, '$.body.stringValue'), ?))
  AND (? = '' OR json_extract_string(l.content, '$.traceId') = ?)
ORDER BY l.event_timestamp_ns DESC, l.id DESC
LIMIT ?;
