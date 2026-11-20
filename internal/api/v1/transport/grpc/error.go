package grpc

import (
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/net/grpc/codes"
	"github.com/alexfalkowski/go-service/v3/net/grpc/status"
)

func (s *Server) error(err error) error {
	switch {
	case errors.Is(err, storage.ErrInvalidQuery):
		return status.SafeError(codes.InvalidArgument, err)
	case errors.Is(err, context.Canceled):
		return status.SafeError(codes.Canceled, err)
	case errors.Is(err, context.DeadlineExceeded):
		return status.SafeError(codes.DeadlineExceeded, err)
	default:
		return status.SafeError(codes.Unavailable, err)
	}
}
