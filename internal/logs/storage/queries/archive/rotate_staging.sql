UPDATE log_archive_batches
SET staging_order = nextval('log_id')
WHERE id = ?::UUID;
