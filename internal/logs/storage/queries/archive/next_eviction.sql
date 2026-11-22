UPDATE log_archive_batches
SET eviction_attempted_at = current_timestamp
WHERE id = (
    SELECT b.id
    FROM log_archive_batches b
    WHERE b.published_at IS NOT NULL
      AND b.published_sha256 IS NOT NULL
      AND b.staging_cleaned_at IS NOT NULL
      AND b.evicted_at IS NULL
      AND NOT EXISTS (
          SELECT 1 FROM log_archive_members m
          JOIN logs l ON l.id = m.log_id
          WHERE m.batch_id = b.id AND l.received_timestamp_ns >= ?::HUGEINT)
    ORDER BY coalesce(b.eviction_attempted_at, b.published_at), b.published_at, b.id
    LIMIT 1
)
RETURNING id::VARCHAR, archive_day::VARCHAR, published_sha256;
