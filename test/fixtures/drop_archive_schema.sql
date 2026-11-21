-- Restore the pre-archive schema after removing publication schema changes.
DROP VIEW log_archive_rows;
DROP TABLE log_archive_members;
DROP TABLE log_archive_batches;
DELETE FROM goose_db_version WHERE version = 2;
