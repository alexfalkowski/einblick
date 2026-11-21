INSERT INTO log_archive_uploads (batch_id, parquet_sha256) VALUES (?::UUID, ?)
ON CONFLICT DO NOTHING;
