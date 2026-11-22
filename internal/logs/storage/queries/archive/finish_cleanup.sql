UPDATE log_archive_batches
SET staging_cleaned_at = current_timestamp, parquet_sha256 = NULL
WHERE id = ?::UUID;
