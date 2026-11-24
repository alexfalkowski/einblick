UPDATE logs
SET received_timestamp_ns = received_timestamp_ns - ?,
    event_timestamp_ns = event_timestamp_ns - CASE WHEN timestamp_ns = 0 AND observed_timestamp_ns = 0 THEN ? ELSE 0 END
WHERE received_timestamp_ns >= ?
  AND id NOT IN (SELECT log_id FROM log_archive_members);
