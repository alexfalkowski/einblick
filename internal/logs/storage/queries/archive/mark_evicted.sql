UPDATE log_archive_batches
SET evicted_at = make_timestamp(epoch_us(current_timestamp)), object_stored_at = ?::TIMESTAMP
WHERE id = ?::UUID;
