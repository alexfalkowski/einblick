-- +goose Up
CREATE SEQUENCE log_archive_queue_order;

CREATE TABLE log_archive_batches (
    id UUID PRIMARY KEY,
    archive_day DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT current_timestamp,
    content_sha256 VARCHAR,
    parquet_sha256 VARCHAR,
    published_at TIMESTAMP,
    published_sha256 VARCHAR,
    staging_cleaned_at TIMESTAMP,
    evicted_at TIMESTAMP,
    object_stored_at TIMESTAMP,
    staging_order BIGINT NOT NULL,
    publication_order BIGINT,
    eviction_order BIGINT
);

CREATE TABLE log_archive_members (
    log_id BIGINT PRIMARY KEY,
    batch_id UUID NOT NULL
);

CREATE TABLE log_archive_uploads (
    batch_id UUID NOT NULL,
    parquet_sha256 VARCHAR NOT NULL,
    PRIMARY KEY (batch_id, parquet_sha256)
);

CREATE VIEW log_archive_rows AS
SELECT m.batch_id, l.id AS log_id, l.timestamp_ns, l.observed_timestamp_ns,
       l.received_timestamp_ns, l.event_timestamp_ns, r.content::VARCHAR AS resource,
       s.content::VARCHAR AS scope, l.content::VARCHAR AS record
FROM log_archive_members m
JOIN logs l ON l.id = m.log_id
JOIN log_scopes s ON s.id = l.scope_id
JOIN log_resources r ON r.id = s.resource_id;
