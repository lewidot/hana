app [Context, program] {
	pf: platform "https://github.com/roc-lang/basic-webserver/releases/download/0.15.0/HcMFsVT26qeMvqWtG5rfNhVMWjceYbKh1An4uYpheBVW.tar.zst",
	hana: "../package/main.roc",
}

import pf.Server
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
		|> Server.respond
		|> Ok

routes = |request, _context| {
	path = Hana.path(request)?

	match path {
		[] => home(request)
		["hello"] => hello(request)
		["hello", name] => hello_name(request, name)
		_ => Hana.halt(Hana.not_found)
	}
}

home = |request| {
	Hana.require_method(request, [GET])?

	Ok(Hana.text("Hello from Hana!"))
}

hello = |_request|
	Ok(Hana.text("Hello, world!"))

hello_name = |_request, name|
	if name == "hana" {
		Err(InvalidName(name))
	} else {
		Ok(Hana.text("Hello, ${name}!"))
	}
