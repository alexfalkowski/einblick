package migrate

import "github.com/alexfalkowski/go-signal/v2"

// Module registers schema recovery before transport startup. The duckdb package
// opens and closes the shared connection; the migrator never closes it.
var Module = signal.Module(
	signal.Constructor(NewMigrator),
	signal.Register(register),
)

func register(lc signal.Lifecycle, migrator *Migrator) {
	lc.Append(signal.Hook{
		OnStart: migrator.Migrate,
	})
}
