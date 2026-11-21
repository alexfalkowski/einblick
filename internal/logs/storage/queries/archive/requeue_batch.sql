UPDATE log_archive_batches
SET parquet_sha256 = NULL
WHERE id = ?::UUID;
