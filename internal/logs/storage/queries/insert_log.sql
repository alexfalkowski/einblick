INSERT INTO logs (scope_id, timestamp_ns, observed_timestamp_ns, received_timestamp_ns, event_timestamp_ns, content)
VALUES (?, ?, ?, ?, coalesce(nullif(?::UBIGINT, 0), nullif(?::UBIGINT, 0), ?::UBIGINT), ?);
