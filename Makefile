# Enable native dependencies for DuckDB (DEP-001).
static := 0

include bin/build/make/help.mak
include bin/build/make/http.mak
include bin/build/make/git.mak
include bin/build/make/claude.mak
include bin/build/make/codex.mak
