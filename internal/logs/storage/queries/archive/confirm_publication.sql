UPDATE log_archive_batches
SET published_at = current_timestamp, published_sha256 = ?
WHERE id = ?::UUID;
