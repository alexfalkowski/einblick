SELECT id::VARCHAR, archive_day::VARCHAR, coalesce(content_sha256, ''), staging_order
FROM log_archive_batches
WHERE parquet_sha256 IS NULL AND published_at IS NULL
ORDER BY staging_order
LIMIT 1;
