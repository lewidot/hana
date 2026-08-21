import http.Response
import http.Method

Hana :: [].{

	## Return a plain text response with status code 200: OK from a route handler.
	##
	## The `content-type` header will be set to `text/plain; charset=utf-8`.
	text : Str -> Try(Route(Response, stream), e)
	text = |body| response(text_response(200, body))

	## Create a plain text response with the given status code.
	##
	## The `content-type` header will be set to `text/plain; charset=utf-8`.
	text_response : U16, Str -> Response
	text_response = |status, body|
		Response.from_status(status)
			.add_header("Content-Type", "text/plain; charset=utf-8")
			.with_body(Str.to_utf8(body))

	## Create an empty response with status code 400: Bad request.
	bad_request : Response
	bad_request = Response.from_status(400)

	## Create an empty response with status code 404: Not found.
	not_found : Response
	not_found = Response.from_status(404)

	## Create an empty response with status code 501: Not implemented.
	not_implemented : Response
	not_implemented = Response.from_status(501)

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

		Response.from_status(405)
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

	## A route result that is either an ordinary response or an event stream.
	Route(response, stream) := [Response(response), EventStream(stream)]

	## Return an ordinary response from a route handler.
	response : response -> Try(Route(response, stream), e)
	response = |value|
		Ok(Response(value))

	## Return an event stream from a route handler.
	event_stream : stream -> Try(Route(response, stream), e)
	event_stream = |value|
		Ok(EventStream(value))

	## Resolve a route result using the application's error handler and the
	## platform's response functions.
	outcome : Try(Route(response, stream), e), (e -> response), (response -> outcome), (stream -> outcome) -> outcome
	outcome = |result, handle_error, respond, stream|
		match result {
			Ok(Response(value)) => respond(value)
			Ok(EventStream(value)) => stream(value)
			Err(error) => respond(handle_error(error))
		}
}
