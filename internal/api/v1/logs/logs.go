package logs

import "github.com/alexfalkowski/einblick/internal/logs/storage"

// NewService uses the existing log repository and its query budget.
func NewService(repo storage.Repository) *Service {
	return &Service{repo: repo}
}

// Service adapts local queries to the generated v1 contract for both API transports.
type Service struct {
	repo storage.Repository
}
