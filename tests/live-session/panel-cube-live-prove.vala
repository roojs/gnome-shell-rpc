/**
 * Live logged-in session: horizontal panel drag via compositor virtual
 * pointer; workspace index must change.
 *
 *   XDG_RUNTIME_DIR=/run/user/1000 \
 *   MUTTER_RPC_SOCKET=$XDG_RUNTIME_DIR/mutter-rpc.sock \
 *   ./build/tests/live-session/panel-cube-live-prove
 *
 * Pass: `panel-cube-live-prove: ok before=N after=M`
 * Fail: `panel-cube-live-prove: miss <reason>`
 */

private const string TAG = "panel-cube-live-prove";

private static int workspace_index(OLLMrpc.Client client)
{
	try {
		var resp = client.call_poll(new OLLMrpc.Request() {
			method = "Meta-Display.get_active_workspace_index",
		});
		if (resp.retval.type() == GLib.Type.INVALID) {
			stderr.printf("%s: miss workspace-index empty\n", TAG);
			return -1;
		}
		return resp.retval.get_int();
	} catch (GLib.Error e) {
		stderr.printf("%s: miss workspace-index %s\n", TAG, e.message);
		return -1;
	}
}

private static bool fire_key(OLLMrpc.Client client, uint keyval, uint modifiers)
{
	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gsr-Clutter-Actor.fire_key",
			args = OLLMrpc.args("uu", keyval, modifiers),
		});
		return true;
	} catch (GLib.Error e) {
		stderr.printf("%s: miss fire_key %s\n", TAG, e.message);
		return false;
	}
}

private static bool pointer_drag(
	OLLMrpc.Client client,
	double x0,
	double y0,
	double x1,
	double y1,
	int steps
) {
	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gsr-Clutter-Actor.pointer_drag",
			args = OLLMrpc.args("ddddi", x0, y0, x1, y1, steps),
		});
		return true;
	} catch (GLib.Error e) {
		stderr.printf("%s: miss pointer_drag %s\n", TAG, e.message);
		return false;
	}
}

public int main(string[] args)
{
	OLLMrpc.Daemon.rpc_register();

	var socket_path = GLib.Environment.get_variable("MUTTER_RPC_SOCKET");
	if (socket_path == null || socket_path.length == 0) {
		var runtime = GLib.Environment.get_variable("XDG_RUNTIME_DIR");
		if (runtime != null && runtime.length > 0) {
			socket_path = GLib.Path.build_filename(runtime, "mutter-rpc.sock");
		} else {
			socket_path = "/tmp/mutter-rpc.sock";
		}
	}

	var client = new OLLMrpc.Client("", "", socket_path) {
		live_handles = true,
		debug = false,
	};

	var loop = new GLib.MainLoop();
	bool connected = false;
	string connect_err = "";
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, TAG),
	}, null, (obj, res) => {
		try {
			connected = client.connect.end(res);
			if (!connected) {
				connect_err = client.connect_error;
			}
		} catch (GLib.Error e) {
			connect_err = e.message;
		}
		loop.quit();
	});
	loop.run();
	if (!connected) {
		stderr.printf("%s: miss connect %s\n", TAG, connect_err);
		return 1;
	}

	var before = workspace_index(client);
	if (before < 0) {
		return 1;
	}

	/* Match headless smoke: 1200 → 730 at y=10 (stops before the clock). */
	if (!pointer_drag(client, 1200.0, 10.0, 730.0, 10.0, 14)) {
		return 1;
	}

	GLib.Thread.usleep(2000 * 1000);

	var after = workspace_index(client);
	if (after < 0) {
		return 1;
	}

	if (after == before) {
		/* If already on last workspace, drag the other way. */
		if (!pointer_drag(client, 730.0, 10.0, 1200.0, 10.0, 14)) {
			return 1;
		}
		GLib.Thread.usleep(2000 * 1000);
		after = workspace_index(client);
		if (after < 0) {
			return 1;
		}
	}

	if (after == before) {
		/* Super+Page_Up — workspace-left in the default schema. */
		const uint SUPER = 1 << 28;
		const uint PAGE_UP = 0xff55;
		if (!fire_key(client, PAGE_UP, SUPER)) {
			return 1;
		}
		GLib.Thread.usleep(800 * 1000);
		var keyed = workspace_index(client);
		if (keyed < 0) {
			return 1;
		}
		if (keyed != before) {
			stderr.printf(
				"%s: miss panel-drag (key ok before=%d after=%d)\n",
				TAG, before, keyed);
			return 1;
		}
		stderr.printf("%s: miss workspace unchanged before=%d after=%d\n",
			TAG, before, after);
		return 1;
	}

	stdout.printf("%s: ok before=%d after=%d\n", TAG, before, after);
	return 0;
}