SELECT count(*)
FROM read_parquet(struct_pack(filename := ?::VARCHAR)::VARIANT, hive_partitioning = false);
