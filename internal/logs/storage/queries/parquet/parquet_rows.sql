WITH records AS NOT MATERIALIZED (
    -- The file is written in log ID order. Read each stored row by file position
    -- so verification also hashes any repeated or out-of-order IDs.
    SELECT file_row_number AS row_position, log_id, timestamp_ns, observed_timestamp_ns,
           received_timestamp_ns, event_timestamp_ns, resource, scope, record
    FROM read_parquet(struct_pack(filename := $1::VARCHAR)::VARIANT,
                      hive_partitioning = false, file_row_number = true)
    WHERE file_row_number BETWEEN $2::BIGINT AND $3::BIGINT
)
