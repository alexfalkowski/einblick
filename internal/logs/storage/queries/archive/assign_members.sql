INSERT INTO log_archive_members (log_id, batch_id)
WITH candidates AS (
    SELECT l.id, ?::BIGINT + strlen(r.content::VARCHAR) + strlen(s.content::VARCHAR) + strlen(l.content::VARCHAR) AS source_bytes
    FROM logs l
    JOIN log_scopes s ON s.id = l.scope_id
    JOIN log_resources r ON r.id = s.resource_id
    WHERE l.event_timestamp_ns // 86400000000000 = (?::DATE - DATE '1970-01-01')
      AND NOT EXISTS (SELECT 1 FROM log_archive_members m WHERE m.log_id = l.id)
    ORDER BY l.id
    LIMIT ?
), sized AS (
    SELECT id, sum(source_bytes) OVER (ORDER BY id) AS total_bytes, row_number() OVER (ORDER BY id) AS position
    FROM candidates
)
SELECT id, ?::UUID FROM sized WHERE total_bytes <= ? OR position = 1;
