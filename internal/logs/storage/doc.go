// Package storage owns local log persistence through its Repository.
// Resource and scope headers are shared within each export, while each record
// retains typed Protobuf JSON and exact unsigned nanosecond timestamps.
package storage
