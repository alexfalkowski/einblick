UPDATE log_archive_batches
SET eviction_order = nextval('log_archive_queue_order')
WHERE id = (
    SELECT b.id
    FROM log_archive_batches b
    WHERE b.published_at IS NOT NULL
      AND b.published_sha256 IS NOT NULL
      AND b.staging_cleaned_at IS NOT NULL
      AND b.evicted_at IS NULL
      AND b.archive_day < ?::DATE
    ORDER BY b.eviction_order
    LIMIT 1
)
RETURNING id::VARCHAR, archive_day::VARCHAR, published_sha256;
