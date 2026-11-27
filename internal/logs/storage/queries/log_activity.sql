SELECT ((event_timestamp_ns::HUGEINT - ?::HUGEINT) // ?::HUGEINT)::INTEGER AS bucket_index,
       count(*) AS records
FROM filtered_logs
GROUP BY bucket_index;
