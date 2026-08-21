# Changelog

## 0.2.0

- Updated `basic-webserver` to `0.16.0`.
- Simplified ordinary handlers to return `Try(http.Response, error)`.
- Added opt-in response and SSE composition through `Hana.Route`.
- Added an SSE example using `Sse.unfold!` and `Server.stream`.
- Added `html`, `json` and explicit-status response helpers.
- Added common status responses, redirects and media type responses.
- Added `Hana.dev_log!` and `Hana.Route.dev_log!` for compact development logs.
- Added `Hana.Route.map_response` for applying response changes without touching streams.
- Changed unsupported CONNECT and OPTIONS `*` targets to return `501 Not Implemented`.
- Removed `with_status`; use `http.Response.with_status` directly.
- Expanded the README with setup, routing, response and SSE examples.

## 0.1.0

- Updated Hana for Roc's new compiler.
- Added path-based routing helpers.
- Added `Hana.halt` for early HTTP responses.
- Added `Hana.resolve` for resolving handler results at the application boundary.
- Added method guards and `405 Method Not Allowed` handling.
- Added standard response helpers such as `text`, `bad_request`, and `not_found`.
