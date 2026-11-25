BEGIN;
ALTER VIEW log_archive_rows RENAME TO complete_log_archive_rows;
CREATE VIEW log_archive_rows AS
SELECT *
FROM complete_log_archive_rows
WHERE event_timestamp_ns // 86400000000000 >
      (SELECT min(event_timestamp_ns) // 86400000000000 FROM logs);
COMMIT;
