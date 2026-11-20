// Package storage owns local log persistence and bounded recent-log queries
// through its Repository.
// Resource and scope headers are shared within each export, while each record
// retains typed Protobuf JSON and exact unsigned nanosecond timestamps.
package storage
