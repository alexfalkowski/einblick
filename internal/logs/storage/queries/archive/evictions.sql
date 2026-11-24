SELECT EXISTS (
    SELECT 1
    FROM log_archive_batches
    WHERE archive_day BETWEEN ?::DATE AND ?::DATE
      AND evicted_at IS NOT NULL
);
