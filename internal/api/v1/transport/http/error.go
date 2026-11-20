package http

import (
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/net/http"
	"github.com/alexfalkowski/go-service/v3/net/http/status"
)

func (s *Server) error(err error) error {
	switch {
	case errors.Is(err, storage.ErrInvalidQuery):
		return status.SafeError(http.StatusBadRequest, err)
	case errors.Is(err, context.Canceled):
		return status.SafeError(http.StatusClientClosedRequest, err)
	case errors.Is(err, context.DeadlineExceeded):
		return status.SafeError(http.StatusGatewayTimeout, err)
	default:
		return status.SafeError(http.StatusServiceUnavailable, err)
	}
}
