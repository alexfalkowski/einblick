package storage

import _ "embed"

//go:embed queries/insert_resource.sql
var insertResourceQuery string

//go:embed queries/insert_scope.sql
var insertScopeQuery string

//go:embed queries/insert_log.sql
var insertLogQuery string

//go:embed queries/list_logs.sql
var listLogsQuery string
