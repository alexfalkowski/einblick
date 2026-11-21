-- Restore the previous archive schema in a disposable test database.
DROP TABLE log_archive_uploads;
ALTER TABLE log_archive_batches DROP COLUMN publication_attempted_at;
ALTER TABLE log_archive_batches DROP COLUMN staging_cleaned_at;
ALTER TABLE log_archive_batches DROP COLUMN published_sha256;
ALTER TABLE log_archive_batches DROP COLUMN published_at;
DELETE FROM goose_db_version WHERE version = 3;
