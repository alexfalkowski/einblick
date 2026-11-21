COPY (
    SELECT log_id, timestamp_ns, observed_timestamp_ns, received_timestamp_ns,
           event_timestamp_ns, resource, scope, record
    FROM log_archive_rows
    WHERE batch_id = ?::UUID
    ORDER BY log_id
) TO (?) (FORMAT PARQUET);
