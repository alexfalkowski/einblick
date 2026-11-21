-- +goose Up
ALTER TABLE log_archive_batches ADD COLUMN published_at TIMESTAMP;
ALTER TABLE log_archive_batches ADD COLUMN published_sha256 VARCHAR;
ALTER TABLE log_archive_batches ADD COLUMN staging_cleaned_at TIMESTAMP;
ALTER TABLE log_archive_batches ADD COLUMN publication_attempted_at TIMESTAMP;

CREATE TABLE log_archive_uploads (
    batch_id UUID NOT NULL,
    parquet_sha256 VARCHAR NOT NULL,
    PRIMARY KEY (batch_id, parquet_sha256)
);
