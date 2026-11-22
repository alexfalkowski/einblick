-- +goose Up
ALTER TABLE log_archive_batches ADD COLUMN evicted_at TIMESTAMP;
ALTER TABLE log_archive_batches ADD COLUMN eviction_attempted_at TIMESTAMP;
