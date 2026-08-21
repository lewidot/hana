app [Context, program] {
	pf: platform "https://github.com/roc-lang/basic-webserver/releases/download/0.16.0/42jC1JT3auhHSmv2Ah8mW5F2MXiAakq1UQQ4NQceQjXw.tar.zst",
	hana: "../package/main.roc",
}

import pf.Server
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
		InvalidName(_name) => Hana.bad_request
	}

respond! : Server.Request, Context => Try(Server.Outcome, [ServerErr(Str), ..])
respond! = |request, context|
	routes(request, context)
		|> Hana.resolve(handle_error)
		|> add_default_headers
		|> Hana.dev_log!(request, Stderr.line!)
		|> Server.respond
		|> Ok

add_default_headers = |response|
	response.add_header("X-Content-Type-Options", "nosniff")

routes = |request, _context| {
	path = Hana.path(request)?

	match path {
		[] => home(request)
		["hello"] => hello(request)
		["hello", name] => hello_name(request, name)
		["html"] => html(request)
		["json"] => json(request)
		_ => Ok(Hana.not_found)
	}
}

home = |request| {
	Hana.require_method(request, [GET])?

	Hana.text("Hello from Hana!")
}

hello = |_request|
	Hana.text("Hello, world!")

html = |_request|
	Hana.html("<h1>Hello, world!</h1>")

json = |_request|
	Hana.json("{\"message\":\"Hello, world!\"}")

hello_name = |_request, name|
	match name {
		"hana" => Err(InvalidName(name))
		_ => Hana.text("Hello, ${name}!")
	}
