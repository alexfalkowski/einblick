INSERT INTO log_archive_members (log_id, batch_id)
SELECT l.id, ?::UUID
FROM logs l
WHERE l.event_timestamp_ns // 86400000000000 = (?::DATE - DATE '1970-01-01')
  AND l.received_timestamp_ns < ?::UBIGINT
  AND NOT EXISTS (SELECT 1 FROM log_archive_members m WHERE m.log_id = l.id);
