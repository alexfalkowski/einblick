SELECT count(*), coalesce(sum(strlen(l.content::VARCHAR)), 0)::BIGINT,
       min(l.received_timestamp_ns),
       (SELECT coalesce(max(published_at), TIMESTAMP '1970-01-01')
        FROM log_archive_batches)
FROM logs l
LEFT JOIN log_archive_members m ON m.log_id = l.id
LEFT JOIN log_archive_batches b ON b.id = m.batch_id
WHERE b.published_at IS NULL;
