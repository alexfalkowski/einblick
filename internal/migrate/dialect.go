package migrate

import (
	"embed"
	"fmt"

	"github.com/alexfalkowski/go-service/v3/bytes"
	"github.com/pressly/goose/v3/database/dialect"
)

//go:embed queries
var queries embed.FS

const (
	createTable        = "queries/create_table.sql"
	insertVersion      = "queries/insert_version.sql"
	deleteVersion      = "queries/delete_version.sql"
	migrationByVersion = "queries/migration_by_version.sql"
	listMigrations     = "queries/list_migrations.sql"
	latestVersion      = "queries/latest_version.sql"
)

// newQuerier loads the required DuckDB history queries during startup.
// The migration module injects the resulting querier into NewMigrator.
func newQuerier() (dialect.Querier, error) {
	statements := make(querier)
	for _, path := range []string{createTable, insertVersion, deleteVersion, migrationByVersion, listMigrations, latestVersion} {
		data, err := queries.ReadFile(path)
		if err != nil {
			return nil, fmt.Errorf("migrate: load history queries: %w", err)
		}
		statements[path] = bytes.String(data)
	}
	return statements, nil
}

// querier supplies DuckDB SQL to Goose's migration history store.
// A history row records application; queries derive Goose's boolean status.
type querier map[string]string

// CreateTable returns SQL to create the history table and its DuckDB ID sequence.
func (q querier) CreateTable(tableName string) string {
	return fmt.Sprintf(q[createTable], tableName)
}

// InsertVersion consumes Goose's version and always-true applied parameters.
// The history row records application with its UTC timestamp.
func (q querier) InsertVersion(tableName string) string {
	return fmt.Sprintf(q[insertVersion], tableName)
}

// DeleteVersion returns SQL to remove history rows for a bound version.
func (q querier) DeleteVersion(tableName string) string {
	return fmt.Sprintf(q[deleteVersion], tableName)
}

// GetMigrationByVersion returns SQL selecting applied_at and true for a bound
// version, using the most recently inserted row if the version is repeated.
func (q querier) GetMigrationByVersion(tableName string) string {
	return fmt.Sprintf(q[migrationByVersion], tableName)
}

// ListMigrations returns SQL selecting version and true in reverse
// insertion order, independently of the numerical order of migration versions.
func (q querier) ListMigrations(tableName string) string {
	return fmt.Sprintf(q[listMigrations], tableName)
}

// GetLatestVersion returns SQL selecting the greatest recorded version,
// or NULL when the history table is empty.
func (q querier) GetLatestVersion(tableName string) string {
	return fmt.Sprintf(q[latestVersion], tableName)
}
