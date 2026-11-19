-- The fixture's fourth record repeats its first timestamp across resources.
CREATE UNIQUE INDEX log_write_conflict ON logs(timestamp_ns);
