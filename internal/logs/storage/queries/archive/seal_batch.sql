UPDATE log_archive_batches
SET content_sha256 = ?
WHERE id = ?::UUID;
