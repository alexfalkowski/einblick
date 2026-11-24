INSERT INTO log_archive_batches (id, archive_day, content_sha256, created_at, publication_order)
VALUES (?::UUID, ?::DATE, ?, make_timestamp(epoch_us(current_timestamp)), nextval('log_archive_queue_order'));
