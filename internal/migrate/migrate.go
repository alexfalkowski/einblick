package migrate

import (
	"embed"
	"fmt"

	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/io"
	"github.com/pressly/goose/v3"
	"github.com/pressly/goose/v3/database"
	"github.com/pressly/goose/v3/database/dialect"
)

//go:embed migrations/*.sql
var migrations embed.FS

// NewMigrator configures Goose with the shared connection, the injected
// migration-history querier, and the embedded migrations.
func NewMigrator(db *sql.DB, querier dialect.Querier) (*Migrator, error) {
	store, err := database.NewStoreFromQuerier(goose.DefaultTablename, querier)
	if err != nil {
		return nil, err
	}

	files, err := io.Sub(migrations, "migrations")
	if err != nil {
		return nil, err
	}

	provider, err := goose.NewProvider(goose.DialectCustom, db, files, goose.WithStore(store))
	if err != nil {
		return nil, err
	}

	return &Migrator{provider: provider}, nil
}

// Migrator checks compatibility and applies pending local schema migrations.
// Each migration and its history row commit together. Earlier completed
// migrations survive a later failure; startup returns that failure without
// accepting traffic. Only the application's startup lifecycle runs migrations.
type Migrator struct {
	provider *goose.Provider
}

// Migrate applies pending up migrations with ctx. A database newer than this
// binary's embedded migrations fails startup without rewriting its version.
// It never automatically downgrades a schema.
func (m *Migrator) Migrate(ctx context.Context) error {
	sources := m.provider.ListSources()
	target := sources[len(sources)-1].Version

	version, err := m.provider.GetDBVersion(ctx)
	if err != nil {
		return err
	}
	if version > target {
		return fmt.Errorf("migrate: unsupported storage schema version %d (supported: %d)", version, target)
	}

	_, err = m.provider.Up(ctx)
	return err
}
