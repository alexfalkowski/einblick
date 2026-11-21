# Enable native dependencies for DuckDB (DEP-001).
static := 0

include bin/build/make/help.mak
include bin/build/make/grpc.mak
include bin/build/make/git.mak
include bin/build/make/claude.mak
include bin/build/make/codex.mak

.PHONY: features-storage features-archive features-queries features-site features-service \
	coverage-workspace-stage coverage-workspace-restore

override export partition := $(value partition)

# Run durable log storage and schema migration features.
features-storage:
	@$(MAKE) features tags="@storage"

# Run local log archive features.
features-archive:
	@$(MAKE) features tags="@archive"

# Run recent log query features.
features-queries:
	@$(MAKE) features tags="@queries"

# Run Logs site features.
features-site:
	@$(MAKE) features tags="@site"

# Run health, telemetry receipt, and other features outside the four tagged groups.
features-service:
	@$(MAKE) features tags="not (@storage or @archive or @queries or @site)"

# Stage raw coverage profiles in a CircleCI workspace partition (set partition to the feature group).
coverage-workspace-stage:
	@./scripts/coverage-workspace stage "$$partition"

# Restore raw CircleCI coverage profiles to test/reports for merging.
coverage-workspace-restore:
	@./scripts/coverage-workspace restore
