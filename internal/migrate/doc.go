// Package migrate applies embedded application schema migrations before serving.
// Goose owns migration transactions and history; DuckDB owns the shared connection.
package migrate
