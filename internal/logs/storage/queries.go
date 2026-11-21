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

//go:embed queries/archive/next_batch.sql
var nextBatchQuery string

//go:embed queries/archive/next_day.sql
var nextDayQuery string

//go:embed queries/archive/assign_members.sql
var assignMembersQuery string

//go:embed queries/archive/source_rows.sql
var sourceRowsQuery string

//go:embed queries/archive/insert_batch.sql
var insertBatchQuery string

//go:embed queries/archive/complete_batch.sql
var completeBatchQuery string

//go:embed queries/archive/completed_batches.sql
var completedBatchesQuery string

//go:embed queries/archive/requeue_batch.sql
var requeueBatchQuery string

//go:embed queries/parquet/copy_batch.sql
var copyBatchQuery string

//go:embed queries/parquet/parquet_rows.sql
var parquetRowsQuery string
