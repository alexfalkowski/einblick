package static

import (
	"crypto/sha256"
	"encoding/hex"
	"maps"
	"text/template"

	"github.com/alexfalkowski/go-service/v3/io"
	"github.com/alexfalkowski/go-service/v3/net/http/mvc"
	"github.com/alexfalkowski/go-service/v3/strings"
)

var assetNames = []string{"logs.css", "logs.js"}

// Register serves the embedded Logs stylesheet and request-status script to browsers.
func Register(server *mvc.Server) {
	for _, name := range assetNames {
		server.StaticFile("/assets/"+name, "static/"+name, mvc.WithStaticUnauthenticated())
	}
}

func assetFunctions(functions template.FuncMap, fs io.FS) (template.FuncMap, error) {
	urls := make(map[string]string, len(assetNames))
	for _, name := range assetNames {
		content, err := io.ReadFile(fs, "static/"+name)
		if err != nil {
			return nil, err
		}

		hash := sha256.Sum256(content)
		urls[name] = strings.Concat("/assets/", name, "?v=", hex.EncodeToString(hash[:]))
	}

	functions = maps.Clone(functions)
	functions["assetURL"] = func(name string) string {
		return urls[name]
	}

	return functions, nil
}
