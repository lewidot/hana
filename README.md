# hana 🌸

Hana is a small web framework for Roc's new compiler. It adds a few conventions
on top of [`basic-webserver`](https://github.com/roc-lang/basic-webserver):

- route with normal pattern matching
- use `?` to stop a handler with an HTTP response
- build common text, HTML, JSON and status responses
- keep `http.Response` available for headers and other changes
- opt into server-sent events when an application needs them

The aim is to remove repetitive request handling without hiding how the server
works. There is no routing DSL or application runtime in Hana.

This project follows the nightly Roc compiler and is still moving with it.

## basic-webserver

`basic-webserver` owns the listener, request body, response transport, files,
logging and SSE runtime. Hana is the application layer around it.

A normal request follows this path:

```text
Server.Request -> Hana handler -> http.Response -> Server.respond
```

Hana itself only depends on `roc-lang/http`. It is designed around the request
shape exposed by `basic-webserver`, then uses `Server.respond` and
`Server.stream` at the edge of the application.

## App setup

An application needs the platform, Hana and the three functions expected by
`basic-webserver`:

```roc
app [Context, program] {
	pf: platform "https://github.com/roc-lang/basic-webserver/releases/download/0.16.0/42jC1JT3auhHSmv2Ah8mW5F2MXiAakq1UQQ4NQceQjXw.tar.zst",
	hana: "../package/main.roc",
}

import pf.Server
import hana.Hana

Context : {}

program = { init!, respond!, shutdown! }

init! = || Ok({ config: Server.default_config, context: {} })
shutdown! = |_reason, _context| Ok({})
```

Use an application context when handlers need shared state such as a database
pool or configuration.

## Routing

Routes are a match over path segments. Handlers return `Try(Response, error)`:

```roc
routes = |request, _context| {
	path = Hana.path(request)?

	match path {
		[] => home(request)
		["hello", name] => hello(request, name)
		_ => Ok(Hana.not_found)
	}
}
```

Guards use `?` to stop the current handler:

```roc
home = |request| {
	Hana.require_method(request, [GET])?
	Hana.text("Hello from Hana!")
}
```

`Hana.halt(response)` puts an intentional response in the error channel. This
lets path handling, method checks and application code share the same early
return style.

Resolve those errors once, at the application boundary:

```roc
handle_error = |error|
	match error {
		Halt(response) => response
		InvalidName(_) => Hana.bad_request
	}

respond! = |request, context|
	routes(request, context)
		|> Hana.resolve(handle_error)
		|> Server.respond
		|> Ok
```

## Responses

The common body helpers finish a handler with status `200`:

```roc
Hana.text("Hello")
Hana.html("<h1>Hello</h1>")
Hana.json("{\"message\":\"Hello\"}")
```

The `_response` versions return a raw `http.Response` with an explicit status:

```roc
Hana.json_response(201, body)
	.add_header("Location", "/items/1")
```

Status helpers such as `bad_request`, `not_found`, `no_content` and
`internal_server_error` are also raw responses. They can be returned with `Ok`,
passed to `Hana.halt`, or returned by `handle_error`.

Response changes remain plain functions, so they fit directly into the
pipeline:

```roc
add_default_headers = |response|
	response.add_header("X-Content-Type-Options", "nosniff")

respond! = |request, context|
	routes(request, context)
		|> Hana.resolve(handle_error)
		|> add_default_headers
		|> Server.respond
		|> Ok
```

For a small development log, inject a platform writer:

```roc
|> Hana.dev_log!(request, Stderr.line!)
```

This prints lines such as `200 GET /`. Use the server's JSON access logger when
transport completion, byte counts or SSE lifetime matter.

## Server-sent events

Response-only applications do not need a different handler type. Applications
with SSE opt into `Hana.Route` where the response and stream branches meet:

```roc
routes! = |request, _context| {
	path = Hana.path(request)?

	match path {
		["events"] => events!(request) |> Hana.Route.event_stream
		_ => response_routes(request, path) |> Hana.Route.response
	}
}
```

Resolve and convert the mixed route at the server boundary:

```roc
respond! = |request, context|
	routes!(request, context)
		|> Hana.Route.resolve(handle_error)
		|> Hana.Route.to_outcome(Server.respond, Server.stream)
		|> Ok
```

`Hana.Route.map_response` applies headers or other response changes without
touching an event stream. The stream itself remains a `pf.Sse.Source`, so
`basic-webserver` keeps ownership of admission, framing, backpressure and
disconnect handling.

See [`examples/hello.roc`](examples/hello.roc) and
[`examples/sse.roc`](examples/sse.roc) for complete applications.
