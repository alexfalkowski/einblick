SELECT id::VARCHAR, archive_day::VARCHAR, evicted_at IS NOT NULL
FROM log_archive_batches
WHERE archive_day BETWEEN ?::DATE AND ?::DATE;
