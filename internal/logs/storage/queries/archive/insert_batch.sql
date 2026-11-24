INSERT INTO log_archive_batches (id, archive_day, created_at, staging_order, publication_order)
VALUES (?::UUID, ?::DATE, make_timestamp(epoch_us(current_timestamp)), nextval('log_id'), nextval('log_archive_queue_order'));
