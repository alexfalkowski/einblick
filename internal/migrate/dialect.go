package migrate

import "fmt"

// Querier supplies DuckDB SQL to Goose's migration history store. Its zero
// value is ready to use. Table names are interpolated as trusted identifiers;
// the service supplies Goose's fixed history-table name.
// A history row records application; queries derive Goose's boolean status.
type Querier struct{}

// CreateTable returns SQL to create the history table and its DuckDB ID sequence.
func (Querier) CreateTable(tableName string) string {
	return fmt.Sprintf(createTableQuery, tableName)
}

// InsertVersion consumes Goose's version and always-true applied parameters.
// Only the version is stored; the history row itself records application.
func (Querier) InsertVersion(tableName string) string {
	return fmt.Sprintf(insertVersionQuery, tableName)
}

// DeleteVersion returns SQL to remove history rows for a bound version.
func (Querier) DeleteVersion(tableName string) string {
	return fmt.Sprintf(deleteVersionQuery, tableName)
}

// GetMigrationByVersion returns SQL selecting applied_at and true for a bound
// version, using the most recently inserted row if the version is repeated.
func (Querier) GetMigrationByVersion(tableName string) string {
	return fmt.Sprintf(migrationByVersionQuery, tableName)
}

// ListMigrations returns SQL selecting version and true in reverse
// insertion order, independently of the numerical order of migration versions.
func (Querier) ListMigrations(tableName string) string {
	return fmt.Sprintf(listMigrationsQuery, tableName)
}

// GetLatestVersion returns SQL selecting the greatest recorded version,
// or NULL when the history table is empty.
func (Querier) GetLatestVersion(tableName string) string {
	return fmt.Sprintf(latestVersionQuery, tableName)
}
