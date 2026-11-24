UPDATE log_archive_batches
SET staging_cleaned_at = make_timestamp(epoch_us(current_timestamp)), parquet_sha256 = NULL
WHERE id = ?::UUID;
