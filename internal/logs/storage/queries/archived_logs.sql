UNION ALL
SELECT log_id, event_timestamp_ns, received_timestamp_ns, resource, scope, record,
       CASE WHEN list_contains(?::VARCHAR[], filename) THEN ''
            ELSE regexp_extract(filename, '/([0-9a-f-]+)\.parquet$', 1) END AS source
FROM read_parquet(?::VARCHAR[], hive_partitioning = false, filename = true)
