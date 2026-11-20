package static

import "github.com/alexfalkowski/go-service/v3/net/http/mvc"

// Register serves the embedded Logs stylesheet and request-status script to browsers.
func Register(server *mvc.Server) {
	server.StaticFile("/assets/logs.css", "static/logs.css", mvc.WithStaticUnauthenticated())
	server.StaticFile("/assets/logs.js", "static/logs.js", mvc.WithStaticUnauthenticated())
}
