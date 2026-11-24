-- +goose Up
ALTER TABLE log_archive_batches ADD COLUMN object_stored_at TIMESTAMP;
ALTER TABLE log_archive_batches ADD COLUMN publication_time_is_utc BOOLEAN DEFAULT false;
ALTER TABLE log_archive_batches ADD COLUMN publication_order BIGINT;
ALTER TABLE log_archive_batches ADD COLUMN eviction_order BIGINT;

CREATE SEQUENCE log_archive_queue_order;

-- Give legacy batches nonpositive positions so they keep their order ahead of new work.
UPDATE log_archive_batches AS batch
SET publication_order = seeded.publication_order, eviction_order = seeded.eviction_order
FROM (
    SELECT id,
           row_number() OVER (ORDER BY coalesce(publication_attempted_at, created_at), created_at, id) -
               count(*) OVER () AS publication_order,
           row_number() OVER (ORDER BY coalesce(eviction_attempted_at, published_at), published_at, id) -
               count(*) OVER () AS eviction_order
    FROM log_archive_batches
) AS seeded
WHERE batch.id = seeded.id;
