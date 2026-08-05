import http.Response
import http.Header

Hana :: [].{

	## Create a HTTP Response with the given plain text body.
	text : Str -> Response.Response
	text = |body| {
		Response.from_status(200)
			.add_header("Content-Type", "text/plain; charset=utf-8")
			.with_body(Str.to_utf8(body))
	}
}
