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

respond! : Server.Request, Context => Try(Server.Outcome, [ServerErr(Str), ..])
respond! = |_request, _context| {
	response = Hana.text("Hello from Hana!")
	Ok(Server.respond(response))
}

shutdown! : Server.ShutdownReason, Context => Try({}, [Exit(I64), ..])
shutdown! = |_reason, _context| Ok({})
