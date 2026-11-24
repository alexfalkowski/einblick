UPDATE log_archive_batches
SET publication_order = nextval('log_archive_queue_order')
WHERE id = (
    SELECT id
    FROM log_archive_batches AS batch
    WHERE (published_at IS NOT NULL AND staging_cleaned_at IS NULL)
       OR (published_at IS NULL AND (
           (?::BOOLEAN AND parquet_sha256 IS NOT NULL)
           OR EXISTS (SELECT 1 FROM log_archive_uploads WHERE batch_id = batch.id)
       ))
    ORDER BY publication_order
    LIMIT 1
)
RETURNING id::VARCHAR, archive_day::VARCHAR, content_sha256, coalesce(parquet_sha256, ''), coalesce(published_sha256, '');
