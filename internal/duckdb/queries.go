package duckdb

import _ "embed"

//go:embed queries/configure_httpfs.sql
var configureHTTPFSQuery string

//go:embed queries/create_r2_secret.sql
var createR2SecretQuery string
