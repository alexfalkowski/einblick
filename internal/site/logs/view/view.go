package view

import "github.com/alexfalkowski/go-service/v3/net/http/mvc"

// NewLogs returns the full page and results fragment for a successful query.
func NewLogs(server *mvc.Server) (*mvc.View, *mvc.View) {
	return server.NewViewPair("logs/view/logs.tmpl")
}

// NewQueryError returns the corresponding localized views for failed queries.
func NewQueryError(server *mvc.Server) (*mvc.View, *mvc.View) {
	return server.NewViewPair("logs/view/error.tmpl")
}
