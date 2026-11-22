DELETE FROM log_resources
WHERE id IN (
    SELECT s.resource_id FROM log_scopes s
    JOIN logs l ON l.scope_id = s.id
    JOIN log_archive_members m ON m.log_id = l.id
    WHERE m.batch_id = $1::UUID)
AND id NOT IN (
    SELECT s.resource_id FROM log_scopes s
    JOIN logs l ON l.scope_id = s.id
    WHERE NOT EXISTS (
        SELECT 1 FROM log_archive_members m
        WHERE m.log_id = l.id AND m.batch_id = $1::UUID));
