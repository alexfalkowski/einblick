ALTER TABLE logs RENAME TO query_source_logs;
CREATE VIEW logs AS
SELECT * FROM query_source_logs
UNION ALL
SELECT l.* REPLACE (l.id - i.range - 1 AS id)
FROM query_source_logs l CROSS JOIN range(1000000000) i
WHERE l.event_timestamp_ns = 1795086245123456792;
