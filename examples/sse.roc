app [Context, program] {
	pf: platform "https://github.com/roc-lang/basic-webserver/releases/download/0.16.0/42jC1JT3auhHSmv2Ah8mW5F2MXiAakq1UQQ4NQceQjXw.tar.zst",
	hana: "../package/main.roc",
}

import pf.Server
import pf.Sse
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
		|> Hana.outcome(handle_error, Server.respond, Server.stream)
		|> Ok

routes! = |request, _context| {
	path = Hana.path(request)?

	match path {
		[] => home(request)
		["events"] => events!(request)
		_ => Hana.response(Hana.not_found)
	}
}

home = |request| {
	Hana.require_method(request, [GET])?

	Hana.text("Run: curl -N http://127.0.0.1:8000/events")
}

events! = |request| {
	Hana.require_method(request, [GET])?

	Hana.event_stream(Sse.unfold!(0, count_transition!))
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
