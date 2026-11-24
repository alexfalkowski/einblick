SELECT row_position, log_id::VARCHAR, timestamp_ns::VARCHAR, observed_timestamp_ns::VARCHAR,
       received_timestamp_ns::VARCHAR, event_timestamp_ns::VARCHAR, resource, scope, record
FROM records;
