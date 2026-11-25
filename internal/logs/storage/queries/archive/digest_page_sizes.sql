SELECT row_position, 40 + coalesce(strlen(resource), 0) + coalesce(strlen(scope), 0) +
       coalesce(strlen(record), 0) AS row_bytes
FROM records;
