UPDATE log_archive_batches
SET eviction_attempted_at = make_timestamp(epoch_us(current_timestamp)),
    eviction_order = nextval('log_archive_queue_order')
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
    ORDER BY b.eviction_order
    LIMIT 1
)
RETURNING id::VARCHAR, archive_day::VARCHAR, published_sha256;
