package migrate

import "embed"

//go:embed migrations/*.sql
var migrations embed.FS

//go:embed queries/create_table.sql
var createTableQuery string

//go:embed queries/insert_version.sql
var insertVersionQuery string

//go:embed queries/delete_version.sql
var deleteVersionQuery string

//go:embed queries/migration_by_version.sql
var migrationByVersionQuery string

//go:embed queries/list_migrations.sql
var listMigrationsQuery string

//go:embed queries/latest_version.sql
var latestVersionQuery string
