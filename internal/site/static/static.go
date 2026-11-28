package static

import "github.com/alexfalkowski/go-service/v3/net/http/mvc"

// Register serves the browser favicon at its conventional URL.
func Register(server *mvc.Server) {
	server.StaticFile("/favicon.ico", "static/favicon.png", mvc.WithStaticUnauthenticated())
}
