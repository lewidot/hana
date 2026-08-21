import http.Response
import http.Method

Hana :: [].{

	## Return a plain text response with status code 200: OK from a route handler.
	##
	## The `content-type` header will be set to `text/plain; charset=utf-8`.
	text : Str -> Try(Response, e)
	text = |body| Ok(text_response(200, body))

	## Create a plain text response with the given status code.
	##
	## The `content-type` header will be set to `text/plain; charset=utf-8`.
	text_response : U16, Str -> Response
	text_response = |status, body|
		Response.from_status(status)
			.add_header("Content-Type", "text/plain; charset=utf-8")
			.with_body(Str.to_utf8(body))

	## Return an HTML response with status code 200: OK from a route handler.
	##
	## The `content-type` header will be set to `text/html; charset=utf-8`.
	html : Str -> Try(Response, e)
	html = |body| Ok(html_response(200, body))

	## Create an HTML response with the given status code.
	##
	## The body is not validated or escaped. The `content-type` header will be
	## set to `text/html; charset=utf-8`.
	html_response : U16, Str -> Response
	html_response = |status, body|
		Response.from_status(status)
			.add_header("Content-Type", "text/html; charset=utf-8")
			.with_body(Str.to_utf8(body))

	## Return a JSON response with status code 200: OK from a route handler.
	##
	## The `content-type` header will be set to `application/json; charset=utf-8`.
	json : Str -> Try(Response, e)
	json = |body| Ok(json_response(200, body))

	## Create a JSON response with the given status code.
	##
	## The body is not validated or encoded. The `content-type` header will be
	## set to `application/json; charset=utf-8`.
	json_response : U16, Str -> Response
	json_response = |status, body|
		Response.from_status(status)
			.add_header("Content-Type", "application/json; charset=utf-8")
			.with_body(Str.to_utf8(body))

	## Create a plain text response with status code 200: OK.
	ok : Response
	ok = text_response(200, "OK")

	## Create a plain text response with status code 201: Created.
	created : Response
	created = text_response(201, "Created")

	## Create a plain text response with status code 202: Accepted.
	accepted : Response
	accepted = text_response(202, "Accepted")

	## Create an empty response with status code 204: No content.
	no_content : Response
	no_content = Response.from_status(204)

	## Create a plain text response with status code 303: See other.
	redirect : Str -> Response
	redirect = |location|
		text_response(303, "You are being redirected: ${location}")
			.add_header("Location", location)

	## Create a plain text response with status code 308: Permanent redirect.
	permanent_redirect : Str -> Response
	permanent_redirect = |location|
		text_response(308, "You are being redirected: ${location}")
			.add_header("Location", location)

	## Create a plain text response with status code 400: Bad request.
	bad_request : Response
	bad_request = text_response(400, "Bad request")

	## Create a plain text response with status code 404: Not found.
	not_found : Response
	not_found = text_response(404, "Not found")

	## Create a plain text response with status code 413: Content too large.
	content_too_large : Response
	content_too_large = text_response(413, "Content too large")

	## Create a response with status code 415: Unsupported media type.
	##
	## The `accept` header will list the supported media types.
	unsupported_media_type : List(Str) -> Response
	unsupported_media_type = |accepted_types|
		text_response(415, "Unsupported media type")
			.add_header("Accept", Str.join_with(accepted_types, ", "))

	## Create a plain text response with status code 422: Unprocessable content.
	unprocessable_content : Response
	unprocessable_content = text_response(422, "Unprocessable content")

	## Create a plain text response with status code 500: Internal server error.
	internal_server_error : Response
	internal_server_error = text_response(500, "Internal server error")

	## Create a plain text response with status code 501: Not implemented.
	not_implemented : Response
	not_implemented = text_response(501, "Not implemented")

	## End the current handler with an intentional HTTP response.
	##
	## This is pure control flow. It does not stop the server.
	halt : Response -> Try(ok, [Halt(Response), ..])
	halt = |response|
		Err(Halt(response))

	## Return the routable path segments of a basic-webserver request.
	##
	## CONNECT authority targets and OPTIONS * are not normal resource paths,
	## so an unsupported request ends with status code 501: Not implemented.
	path :
		request -> Try(List(Str), [Halt(Response), ..])
			where [
				request.target :
					request
						-> [
							Asterisk,
							Authority(authority),
							Resource({ raw_path : Str, .. }),
						],
			]
	path = |request|
		match request.target() {
			Resource({ raw_path, .. }) =>
				Ok(path_segments(raw_path))

			Authority(_) =>
				halt(not_implemented)

			Asterisk =>
				halt(not_implemented)
			}

	## Return the segments of an absolute raw URI path.
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

	## Convert a HEAD request method to GET.
	##
	## This allows an application to handle HEAD requests using its GET handlers.
	routing_method : Method -> Method
	routing_method = |method|
		match method {
			HEAD => GET
			_ => method
		}

	## Create a response with status code 405: Method not allowed.
	##
	## Use this when a request does not have an appropriate method to be handled.
	## The `allow` header will be set to a comma-separated list of the permitted
	## methods.
	method_not_allowed : List(Method) -> Response
	method_not_allowed = |allowed| {
		allow =
			allowed
				.map(Method.to_str)
				|> Str.join_with(", ")

		text_response(405, "Method not allowed")
			.add_header("Allow", allow)
	}

	## Ensure that a request has one of the permitted HTTP methods.
	##
	## HEAD requests are checked as GET requests. If the method is not permitted,
	## the handler ends with status code 405: Method not allowed.
	require_method = |request, allowed| {
		method = routing_method(request.method())

		if allowed.contains(method) {
			Ok({})
		} else {
			halt(method_not_allowed(allowed))
		}
	}

	## Resolve a handler result into a response using the application's error
	## handler.
	resolve : Try(Response, e), (e -> Response) -> Response
	resolve = |result, handle_error|
		match result {
			Ok(response_value) => response_value
			Err(error) => handle_error(error)
		}

	## Write a compact development log line and preserve the response.
	##
	## Pass a platform writer such as `Stderr.line!`. Writer errors are ignored
	## so logging cannot change the response. Use the server's access logger when
	## transport completion, byte counts, or production logging are required.
	dev_log! = |response_value, request, write!| {
		write_dev_log!(response_value.status().to_str(), request, write!)
		response_value
	}

	## Opt-in composition for handlers that return ordinary responses and event
	## streams. Response-only applications do not need this type.
	Route(stream) := [Response(Response), EventStream(stream)].{

		## Adapt an ordinary response handler result for a mixed route.
		response : Try(Response, e) -> Try(Route(stream), e)
		response = |result|
			match result {
				Ok(response_value) => Ok(Response(response_value))
				Err(error) => Err(error)
			}

		## Adapt an event stream handler result for a mixed route.
		event_stream : Try(stream, e) -> Try(Route(stream), e)
		event_stream = |result|
			match result {
				Ok(stream_value) => Ok(EventStream(stream_value))
				Err(error) => Err(error)
			}

		## Resolve a mixed handler result using an ordinary HTTP error response.
		resolve : Try(Route(stream), e), (e -> Response) -> Route(stream)
		resolve = |result, handle_error|
			match result {
				Ok(route) => route
				Err(error) => Response(handle_error(error))
			}

		## Transform an ordinary response while preserving an event stream.
		map_response : Route(stream), (Response -> Response) -> Route(stream)
		map_response = |route, transform|
			match route {
				Response(response_value) => Response(transform(response_value))
				EventStream(stream_value) => EventStream(stream_value)
			}

		## Write a compact development log line and preserve the mixed route.
		##
		## Event streams are logged as selected, not when their transport finishes.
		dev_log! = |route, request, write!| {
			label =
				fold(
					route,
					|response_value| response_value.status().to_str(),
					|_| "SSE",
				)

			write_dev_log!(label, request, write!)
			route
		}

		## Fold an ordinary response or event stream into one value.
		fold : Route(stream), (Response -> result), (stream -> result) -> result
		fold = |route, respond, stream|
			match route {
				Response(response_value) => respond(response_value)
				EventStream(stream_value) => stream(stream_value)
			}

		## Convert a mixed route using the platform's outcome constructors.
		to_outcome : Route(stream), (Response -> outcome), (stream -> outcome) -> outcome
		to_outcome = |route, respond, stream|
			fold(route, respond, stream)
	}
}

write_dev_log! = |label, request, write!| {
	target =
		match request.target() {
			Resource({ raw_path, .. }) => raw_path
			Authority(_) => "<authority>"
			Asterisk => "*"
		}

	method = Method.to_str(request.method())
	write!("${label} ${method} ${target}") ?? {}
}
