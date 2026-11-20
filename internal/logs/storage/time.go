package storage

import (
	"math/big"

	"github.com/alexfalkowski/go-service/v3/time"
)

// Convert seconds and fractional nanoseconds separately: UnixNano overflows for
// supported OTLP timestamps after 2262, before the unsigned range ends in 2554.
func unixNanoseconds(value time.Time) *big.Int {
	seconds := new(big.Int).Mul(big.NewInt(value.Unix()), big.NewInt(int64(time.Second)))
	return seconds.Add(seconds, big.NewInt(int64(value.Nanosecond())))
}

func timestamp(nanoseconds uint64) time.Time {
	//nolint:gosec // Dividing by 1e9 leaves at most 18446744073 seconds, within int64.
	seconds := int64(nanoseconds / uint64(time.Second))
	fraction := time.Duration(nanoseconds % uint64(time.Second))
	return time.Unix(seconds).Add(fraction.Duration()).UTC()
}
