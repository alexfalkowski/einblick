-- Restore the log-only schema in the disposable feature database.
DROP VIEW log_archive_rows;
DROP TABLE log_archive_uploads;
DROP TABLE log_archive_members;
DROP TABLE log_archive_batches;
DROP SEQUENCE log_archive_queue_order;
DELETE FROM goose_db_version WHERE version = 2;
