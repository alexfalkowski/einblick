package site

import (
	"embed"

	"github.com/alexfalkowski/go-service/v3/i18n"
	"github.com/alexfalkowski/go-service/v3/io"
	"github.com/alexfalkowski/go-service/v3/net/http/mvc"
	"golang.org/x/text/language"
)

//go:embed root/layout/*.tmpl
//go:embed logs/view/*.tmpl
//go:embed locales/*.yaml
//go:embed static/*.css static/*.js static/favicon.png
var filesystem embed.FS

// NewFileSystem provides the embedded layouts, views, catalogs, and first-party assets.
func NewFileSystem() io.FS {
	return filesystem
}

// NewCatalog loads the embedded site messages with English as the fallback.
// Catalog loading errors prevent the site from starting.
func NewCatalog(fs io.FS) (*i18n.Catalog, error) {
	return i18n.NewCatalog(language.English, fs, "locales/*.yaml")
}

// NewLayout selects the shared layout for full documents and partial responses.
func NewLayout() *mvc.Layout {
	return mvc.NewLayout("root/layout/full.tmpl", "root/layout/partial.tmpl")
}
