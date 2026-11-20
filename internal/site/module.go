package site

import (
	"github.com/alexfalkowski/einblick/internal/site/logs"
	"github.com/alexfalkowski/einblick/internal/site/static"
	"github.com/alexfalkowski/go-signal/v2"
)

// Module composes the browser features and shared MVC dependencies.
var Module = signal.Module(
	logs.Module,
	static.Module,
	signal.Constructor(NewFileSystem),
	signal.Constructor(NewCatalog),
	signal.Constructor(NewLayout),
)
