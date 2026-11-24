SELECT log_id
FROM log_archive_members
WHERE batch_id = $1::UUID AND log_id > $2::BIGINT
ORDER BY log_id
LIMIT $3;
