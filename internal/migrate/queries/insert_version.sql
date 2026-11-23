INSERT INTO %s (version, applied_at)
SELECT ?, make_timestamp(epoch_us(current_timestamp)) WHERE ?;
