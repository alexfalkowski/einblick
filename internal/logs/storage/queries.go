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

//go:embed queries/filter_logs.sql
var filterLogsQuery string

//go:embed queries/log_activity.sql
var logActivityQuery string

//go:embed queries/local_logs.sql
var localLogsQuery string

//go:embed queries/archived_logs.sql
var archivedLogsQuery string

//go:embed queries/archive/sources.sql
var archiveSourcesQuery string

//go:embed queries/archive/evictions.sql
var archiveEvictionsQuery string

//go:embed queries/archive/backlog.sql
var archiveBacklogQuery string

//go:embed queries/archive/next_batch.sql
var nextBatchQuery string

//go:embed queries/archive/rotate_staging.sql
var rotateStagingQuery string

//go:embed queries/archive/next_day.sql
var nextDayQuery string

//go:embed queries/archive/assign_members.sql
var assignMembersQuery string

//go:embed queries/archive/source_rows.sql
var sourceRowsQuery string

//go:embed queries/archive/insert_batch.sql
var insertBatchQuery string

//go:embed queries/archive/seal_batch.sql
var sealBatchQuery string

//go:embed queries/archive/complete_batch.sql
var completeBatchQuery string

//go:embed queries/archive/completed_batches.sql
var completedBatchesQuery string

//go:embed queries/archive/requeue_batch.sql
var requeueBatchQuery string

//go:embed queries/archive/next_publication.sql
var nextPublicationQuery string

//go:embed queries/archive/record_upload.sql
var recordUploadQuery string

//go:embed queries/archive/has_upload.sql
var hasUploadQuery string

//go:embed queries/archive/confirm_publication.sql
var confirmPublicationQuery string

//go:embed queries/archive/clear_uploads.sql
var clearUploadsQuery string

//go:embed queries/archive/finish_cleanup.sql
var finishCleanupQuery string

//go:embed queries/archive/next_eviction.sql
var nextEvictionQuery string

//go:embed queries/archive/evict_resources.sql
var evictResourcesQuery string

//go:embed queries/archive/evict_scopes.sql
var evictScopesQuery string

//go:embed queries/archive/evict_logs.sql
var evictLogsQuery string

//go:embed queries/archive/evict_members.sql
var evictMembersQuery string

//go:embed queries/archive/mark_evicted.sql
var markEvictedQuery string

//go:embed queries/parquet/parquet_rows.sql
var parquetRowsQuery string

//go:embed queries/archive/digest_page.sql
var digestPageQuery string

//go:embed queries/archive/source_position.sql
var sourcePositionQuery string

//go:embed queries/parquet/parquet_count.sql
var parquetCountQuery string

//go:embed queries/archive/digest_page_sizes.sql
var digestPageSizesQuery string
