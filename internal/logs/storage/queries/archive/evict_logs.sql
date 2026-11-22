DELETE FROM logs
WHERE id IN (SELECT log_id FROM log_archive_members WHERE batch_id = ?::UUID);
