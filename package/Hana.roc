import http.Response
import http.Method

Hana :: [].{
	text : Str -> Response.Response
	text = |body| text_response(200, body)

	text_response : U16, Str -> Response.Response
	text_response = |status, body|
		Response.from_status(status)
			.add_header("Content-Type", "text/plain; charset=utf-8")
			.with_body(Str.to_utf8(body))

	bad_request : Response.Response
	bad_request = Response.from_status(400)

	not_found : Response.Response
	not_found = Response.from_status(404)

	with_status = |response, status|
		response.with_status(status)

	## End the current handler with an intentional HTTP response.
	##
	## This is pure control flow. It does not stop the server.
	halt = |response|
		Err(Halt(response))

	## Extract routeable path segments from a basic-webserver request.
	##
	## CONNECT authority targets and OPTIONS * are not normal resource paths,
	## so they produce an early 400 response.
	path = |request|
		match request.target() {
			Resource({ raw_path, .. }) =>
				Ok(path_segments(raw_path))

			Authority(_) =>
				halt(bad_request)

			Asterisk =>
				halt(bad_request)
			}

	## Split an absolute raw URI path into routeable segments.
	##
	## One leading and one trailing slash are ignored. Internal empty
	## segments remain significant.
	path_segments : Str -> List(Str)
	path_segments = |raw_path| {
		without_leading_slash =
			raw_path
				.split_on("/")
				.drop_first(1)

		match without_leading_slash.last() {
			Ok("") =>
				without_leading_slash.drop_last(1)

			_ =>
				without_leading_slash
			}
	}

	## Catch any HEAD requests and make it so its handled to the GET handler.
	routing_method : Method.Method -> Method.Method
	routing_method = |method|
		match method {
			HEAD => GET
			_ => method
		}

	## Response for when the HTTP method is not allowed.
	method_not_allowed : List(Method.Method) -> Response.Response
	method_not_allowed = |allowed| {
		allow =
			allowed
				.map(Method.to_str)
				|> Str.join_with(", ")

		Response.from_status(405)
			.add_header("Allow", allow)
	}

	## Middleware that ensures the request has a specific HTTP method.
	##
	## Returns an empty response with status code 405: Method not allowed.
	require_method = |request, allowed| {
		method = routing_method(request.method())

		if allowed.contains(method) {
			Ok({})
		} else {
			halt(method_not_allowed(allowed))
		}
	}

	resolve = |result, handle_error|
		match result {
			Ok(response) =>
				response

			Err(error) =>
				handle_error(error)
			}
}
