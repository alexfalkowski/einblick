SELECT id::VARCHAR, archive_day::VARCHAR, content_sha256
FROM log_archive_batches
WHERE parquet_sha256 IS NULL
ORDER BY created_at, id
LIMIT 1;
