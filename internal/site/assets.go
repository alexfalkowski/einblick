package site

import (
	"github.com/alexfalkowski/go-service/v3/io"
	"github.com/alexfalkowski/go-service/v3/net/http/mvc"
)

// NewAssets loads the site's fingerprinted MVC bundles.
// A missing source or invalid manifest prevents the site from starting.
func NewAssets(fs io.FS) (*mvc.Assets, error) {
	assets := []mvc.Asset{
		{Name: "logs.css", Manifest: "logs/assets/logs.css.tmpl"},
		{Name: "logs.js", Manifest: "logs/assets/logs.js.tmpl"},
	}

	return mvc.NewAssets(fs, "/assets", assets, mvc.WithStaticUnauthenticated())
}
