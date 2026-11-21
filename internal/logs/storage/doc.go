// Package storage owns local log persistence, bounded recent-log queries,
// and DuckDB operations for log archival.
// Resource and scope headers are shared within each export, while each record
// retains typed Protobuf JSON and exact unsigned nanosecond timestamps.
package storage
