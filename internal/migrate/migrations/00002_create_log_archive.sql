-- +goose Up
CREATE TABLE log_archive_batches (
    id UUID PRIMARY KEY,
    archive_day DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT current_timestamp,
    content_sha256 VARCHAR NOT NULL,
    parquet_sha256 VARCHAR
);

CREATE TABLE log_archive_members (
    log_id BIGINT PRIMARY KEY,
    batch_id UUID NOT NULL
);

CREATE VIEW log_archive_rows AS
SELECT m.batch_id, l.id AS log_id, l.timestamp_ns, l.observed_timestamp_ns,
       l.received_timestamp_ns, l.event_timestamp_ns, r.content::VARCHAR AS resource,
       s.content::VARCHAR AS scope, l.content::VARCHAR AS record
FROM log_archive_members m
JOIN logs l ON l.id = m.log_id
JOIN log_scopes s ON s.id = l.scope_id
JOIN log_resources r ON r.id = s.resource_id;
