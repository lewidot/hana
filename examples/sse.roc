app [Context, program] {
	pf: platform "https://github.com/roc-lang/basic-webserver/releases/download/0.16.0/42jC1JT3auhHSmv2Ah8mW5F2MXiAakq1UQQ4NQceQjXw.tar.zst",
	hana: "../package/main.roc",
}

import pf.Server
import pf.Sse
import pf.Stderr
import hana.Hana

Context : {}

program = { init!, respond!, shutdown! }

init! : () => Try({ config : Server.Config, context : Context }, [Exit(I64), ..])
init! = || Ok({ config: Server.default_config, context: {} })

shutdown! : Server.ShutdownReason, Context => Try({}, [Exit(I64), ..])
shutdown! = |_reason, _context| Ok({})

handle_error = |error|
	match error {
		Halt(response) => response
	}

respond! : Server.Request, Context => Try(Server.Outcome, [ServerErr(Str), ..])
respond! = |request, context|
	routes!(request, context)
		|> Hana.Route.resolve(handle_error)
		|> Hana.Route.map_response(add_default_headers)
		|> Hana.Route.dev_log!(request, Stderr.line!)
		|> Hana.Route.to_outcome(Server.respond, Server.stream)
		|> Ok

add_default_headers = |response|
	response.add_header("X-Content-Type-Options", "nosniff")

routes! = |request, _context| {
	path = Hana.path(request)?

	match path {
		["events"] => events!(request) |> Hana.Route.event_stream
		_ => response_routes(request, path) |> Hana.Route.response
	}
}

response_routes = |request, path|
	match path {
		[] => home(request)
		_ => Ok(Hana.not_found)
	}

home = |request| {
	Hana.require_method(request, [GET])?

	Hana.text("Run: curl -N http://127.0.0.1:8000/events")
}

events! = |request| {
	Hana.require_method(request, [GET])?

	Ok(Sse.unfold!(0, count_transition!))
}

count_transition! : U64 => Try(Sse.Step(U64), [StreamFailed(Str)])
count_transition! = |count|
	if count > 10 {
		Ok(End)
	} else {
		Ok(
			Emit({
				event: Sse.Event.data(U64.to_str(count)),
				state: count + 1,
				wake: if count == 10 {
					Immediately
				} else {
					After(1000)
				},
			}),
		)
	}
