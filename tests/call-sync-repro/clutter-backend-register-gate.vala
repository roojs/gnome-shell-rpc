/**
 * {@code Clutter-Backend.get_sprite} is only available after
 * {@link Gsr.Server.Clutter.Backend.rpc_register}. Alias registration
 * does not add live methods.
 *
 *   meson compile -C build clutter-backend-register-gate
 *   timeout 5 ./build/tests/call-sync-repro/clutter-backend-register-gate current
 *   timeout 5 ./build/tests/call-sync-repro/clutter-backend-register-gate fixed
 */

private class GateBackend : GLib.Object
{
	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Clutter-Backend", typeof(GateBackend),
			"get_sprite", "tuu",
			"get_pointer_sprite", "t",
			null);
		OLLMrpc.Request.register_live("Clutter-Backend", new GateBackend());
	}
}

static bool has_get_sprite()
{
	if (!OLLMrpc.Request.methods.has_key("Clutter-Backend")) {
		return false;
	}
	return OLLMrpc.Request.methods["Clutter-Backend"].has_key("get_sprite");
}

int main(string[] args)
{
	var mode = "current";
	if (args.length >= 2) {
		mode = args[1];
	}
	if (mode != "current" && mode != "fixed") {
		GLib.stderr.printf("FAIL clutter-backend-register-gate: mode %s\n", mode);
		return 2;
	}

	OLLMrpc.Request.rpc_register();

	if (mode == "fixed") {
		GateBackend.rpc_register();
	}

	var has = has_get_sprite();
	if (mode == "current") {
		if (!has) {
			GLib.stderr.printf(
				"FAIL clutter-backend-register-gate current: get_sprite not registered\n");
			return 1;
		}
		GLib.stderr.printf(
			"PASS clutter-backend-register-gate current: get_sprite registered\n");
		return 0;
	}
	if (!has) {
		GLib.stderr.printf(
			"FAIL clutter-backend-register-gate fixed: get_sprite not registered\n");
		return 1;
	}
	GLib.stderr.printf(
		"PASS clutter-backend-register-gate fixed: get_sprite registered\n");
	return 0;
}