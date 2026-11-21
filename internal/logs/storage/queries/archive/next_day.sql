SELECT uuidv7()::VARCHAR, (DATE '1970-01-01' + (l.event_timestamp_ns // 86400000000000)::INTEGER)::VARCHAR
FROM logs l
WHERE NOT EXISTS (SELECT 1 FROM log_archive_members m WHERE m.log_id = l.id)
ORDER BY l.id
LIMIT 1;
