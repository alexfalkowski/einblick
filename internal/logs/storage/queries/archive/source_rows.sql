SELECT log_id::VARCHAR, timestamp_ns::VARCHAR, observed_timestamp_ns::VARCHAR,
       received_timestamp_ns::VARCHAR, event_timestamp_ns::VARCHAR, resource, scope, record
FROM log_archive_rows
WHERE batch_id = $1::UUID AND log_id = $2::BIGINT;
