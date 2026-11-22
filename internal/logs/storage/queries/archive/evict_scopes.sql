DELETE FROM log_scopes
WHERE id IN (
    SELECT l.scope_id FROM logs l
    JOIN log_archive_members m ON m.log_id = l.id
    WHERE m.batch_id = $1::UUID)
AND id NOT IN (
    SELECT l.scope_id FROM logs l
    WHERE NOT EXISTS (
        SELECT 1 FROM log_archive_members m
        WHERE m.log_id = l.id AND m.batch_id = $1::UUID));
