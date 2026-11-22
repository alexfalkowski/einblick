UPDATE log_archive_batches SET evicted_at = current_timestamp WHERE id = ?::UUID;
