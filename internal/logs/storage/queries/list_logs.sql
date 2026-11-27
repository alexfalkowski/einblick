SELECT id, event_timestamp_ns::VARCHAR, received_timestamp_ns::VARCHAR, resource, scope, record, source
FROM filtered_logs
WHERE (event_timestamp_ns < ?::HUGEINT OR (event_timestamp_ns = ?::HUGEINT
       AND (id < ? OR (id = ? AND source < ?))))
ORDER BY event_timestamp_ns DESC, id DESC, source DESC
LIMIT ?;
