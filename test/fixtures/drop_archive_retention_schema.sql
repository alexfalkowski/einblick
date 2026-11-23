-- Restore the version 4 archive metadata in a disposable database.
ALTER TABLE log_archive_batches DROP COLUMN eviction_order;
ALTER TABLE log_archive_batches DROP COLUMN publication_order;
ALTER TABLE log_archive_batches DROP COLUMN publication_time_is_utc;
ALTER TABLE log_archive_batches DROP COLUMN object_stored_at;
DROP SEQUENCE log_archive_queue_order;
DELETE FROM goose_db_version WHERE version = 5;
