package duckdb

// Config configures the required local database.
type Config struct {
	// Path is a writable database filename on persistent storage. Its parent
	// directory must exist. In-memory databases and DSN parameters are unsupported.
	Path string `yaml:"path,omitempty" json:"path,omitempty" toml:"path,omitempty" validate:"required,ne=:memory:,excludesall=?#"`

	// MemoryLimit is DuckDB's memory_limit value, including its unit (for example
	// 64MiB). DuckDB validates the value; it does not bound total process memory.
	MemoryLimit string `yaml:"memory_limit,omitempty" json:"memory_limit,omitempty" toml:"memory_limit,omitempty" validate:"required"`

	// SpillLimit bounds engine-managed temporary files. DuckDB supplies its
	// default when omitted.
	SpillLimit string `yaml:"spill_limit,omitempty" json:"spill_limit,omitempty" toml:"spill_limit,omitempty"`

	// Threads is DuckDB's positive worker-thread count.
	Threads int `yaml:"threads,omitempty" json:"threads,omitempty" toml:"threads,omitempty" validate:"gt=0"`
}
