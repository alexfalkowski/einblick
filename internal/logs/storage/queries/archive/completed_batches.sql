SELECT id::VARCHAR, archive_day::VARCHAR, content_sha256, parquet_sha256
FROM log_archive_batches
WHERE parquet_sha256 IS NOT NULL;
