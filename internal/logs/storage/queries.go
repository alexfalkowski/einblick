package storage

import (
	"embed"

	"github.com/alexfalkowski/einblick/internal/database/query"
)

//go:embed queries
var queries embed.FS

type statements struct{ query.Set }

func loadStatements() (statements, error) {
	loaded, err := query.Load(queries, "queries")
	return statements{Set: loaded}, err
}
