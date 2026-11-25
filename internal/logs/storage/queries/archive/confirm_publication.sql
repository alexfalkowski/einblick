UPDATE log_archive_batches
SET published_at = make_timestamp(epoch_us(current_timestamp)), published_sha256 = ?,
    eviction_order = nextval('log_archive_queue_order')
WHERE id = ?::UUID;
