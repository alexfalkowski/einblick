SELECT EXISTS (
    SELECT 1 FROM log_archive_uploads WHERE batch_id = ?::UUID AND parquet_sha256 = ?
);
