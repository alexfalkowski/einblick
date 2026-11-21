SELECT log_id::VARCHAR, timestamp_ns::VARCHAR, observed_timestamp_ns::VARCHAR,
       received_timestamp_ns::VARCHAR, event_timestamp_ns::VARCHAR, resource, scope, record
-- Verify the exact file and its stored columns independently of the workspace name.
FROM read_parquet(struct_pack(filename := ?::VARCHAR)::VARIANT, hive_partitioning = false)
ORDER BY log_id;
