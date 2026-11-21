UPDATE log_archive_batches
SET parquet_sha256 = ?
WHERE id = ?::UUID;
