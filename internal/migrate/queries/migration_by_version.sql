SELECT applied_at, TRUE AS applied FROM %s WHERE version = ? ORDER BY id DESC LIMIT 1;
