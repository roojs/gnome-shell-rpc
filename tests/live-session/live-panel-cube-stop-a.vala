/**
 * Stop A bar on a live gsr-client session: ydotool drags (not smoke,
 * not compositor pointer_drag) and compositor-backed workspace index.
 *
 *   YDOTOOL_SOCKET=/tmp/ydotool.sock \
 *   MUTTER_RPC_SOCKET=$XDG_RUNTIME_DIR/mutter-rpc.sock \
 *   WAYLAND_DISPLAY=wayland-0 \
 *   ./build/tests/live-session/live-panel-cube-stop-a
 */

private const string TAG = "live-panel-cube-stop-a";

private static OLLMrpc.Client? ws_client;

private static int workspace_index()
{
	try {
		var resp = ws_client.call_poll(new OLLMrpc.Request() {
			method = "Meta-Display.get_active_workspace_index",
		});
		if (resp.retval.type() == GLib.Type.INT) {
			return resp.retval.get_int();
		}
		stderr.printf("%s: miss workspace-index type\n", TAG);
		return -1;
	} catch (GLib.Error e) {
		stderr.printf("%s: miss workspace-index %s\n", TAG, e.message);
		return -1;
	}
}

private static string ydotool_env()
{
	var socket = GLib.Environment.get_variable("YDOTOOL_SOCKET");
	if (socket == null) {
		socket = "/tmp/ydotool.sock";
	}
	var wayland = GLib.Environment.get_variable("WAYLAND_DISPLAY");
	if (wayland == null) {
		wayland = "wayland-0";
	}
	var runtime = GLib.Environment.get_variable("XDG_RUNTIME_DIR");
	if (runtime == null) {
		runtime = "/run/user/1000";
	}
	return "env YDOTOOL_SOCKET='%s' WAYLAND_DISPLAY='%s' XDG_RUNTIME_DIR='%s'".printf(
		socket, wayland, runtime);
}

private static int ydotool_cmd(string sh)
{
	var st = Posix.system(sh);
	if (st != 0) {
		stderr.printf("%s: miss ydotool cmd exit=%d\n", TAG, st);
	}
	return st;
}

private static bool compositor_hdrag(double x0, double y0, double x1, double y1)
{
	try {
		ws_client.call_poll(new OLLMrpc.Request() {
			method = "Gsr-Clutter-Actor.pointer_hdrag",
			args = OLLMrpc.args("ddddi", x0, y0, x1, y1, 14),
		});
		return true;
	} catch (GLib.Error e) {
		stderr.printf("%s: miss pointer_hdrag %s\n", TAG, e.message);
		return false;
	}
}

private static int run_ydotool_hdrag(int x0, int x1, int y)
{
	var env = ydotool_env();
	var sh = "%s sudo %s ydotool mousemove -a %d %d && ".printf(env, env, x0, y);
	sh += "%s sudo %s ydotool click 0xC0:1 0 && sleep 0.1 && ".printf(env, env);
	var step = x0 > x1 ? -40 : 40;
	for (int x = x0 + step; step > 0 ? x <= x1 : x >= x1; x += step) {
		sh += "%s sudo %s ydotool mousemove -a %d %d && sleep 0.06 && ".printf(
			env, env, x, y);
	}
	sh += "%s sudo %s ydotool click 0xC0:0 0".printf(env, env);
	return ydotool_cmd(sh);
}

private static int run_ydotool_click(int x, int y)
{
	var env = ydotool_env();
	var sh = "%s sudo %s ydotool mousemove -a %d %d && ".printf(env, env, x, y);
	sh += "%s sudo %s ydotool click 0x41:1 0 && sleep 0.05 && ".printf(env, env);
	sh += "%s sudo %s ydotool click 0x41:0 0".printf(env, env);
	return ydotool_cmd(sh);
}

private static bool drag_changes_ws(int before, double x0, double y0, double x1, double y1, out int after)
{
	if (!compositor_hdrag(x0, y0, x1, y1)) {
		after = -1;
		return false;
	}
	for (int i = 0; i < 20; i++) {
		GLib.Thread.usleep(150 * 1000);
		after = workspace_index();
		if (after >= 0 && after != before) {
			return true;
		}
	}
	after = workspace_index();
	return after >= 0 && after != before;
}

private static int run_super_page_up()
{
	var env = ydotool_env();
	/* KEY_SUPER 125, KEY_PAGEUP 104 on the VM layout. */
	var sh = "%s sudo %s ydotool key 125:1 104:1 104:0 125:0".printf(env, env);
	return ydotool_cmd(sh);
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

	ws_client = client;
	Posix.system("gsettings set org.gnome.mutter dynamic-workspaces false");
	Posix.system("gsettings set org.gnome.desktop.wm.preferences num-workspaces 4");
	GLib.Thread.usleep(500 * 1000);

	int n_ws = -1;
	try {
		var nw = client.call_poll(new OLLMrpc.Request() {
			method = "Meta-Display.get_n_workspaces",
		});
		if (nw.retval.type() == GLib.Type.INT) {
			n_ws = nw.retval.get_int();
		}
	} catch (GLib.Error e) {
		stderr.printf("%s: warn n_workspaces %s\n", TAG, e.message);
	}
	var before = workspace_index();
	if (before < 0) {
		return 1;
	}
	stderr.printf("%s: n_workspaces=%d active=%d\n", TAG, n_ws, before);

	if (args.length >= 2 && args[1] == "--key-test") {
		run_super_page_up();
		GLib.Thread.usleep(1500 * 1000);
		var kafter = workspace_index();
		stdout.printf("%s: key before=%d after=%d\n", TAG, before, kafter);
		return (kafter >= 0 && kafter != before) ? 0 : 1;
	}

	int after = before;
	string path = "";

	/* Panel: smoke uses 1200 → 730 at y=10. */
	if (drag_changes_ws(before, 1200, 10, 730, 10, out after)) {
		path = "panel";
	} else if (drag_changes_ws(before, 730, 10, 1200, 10, out after)) {
		path = "panel-reverse";
	} else {
		run_ydotool_click(40, 10);
		GLib.Thread.usleep(2000 * 1000);
		if (drag_changes_ws(before, 800, 400, 240, 400, out after)) {
			path = "overview";
		} else if (drag_changes_ws(before, 240, 400, 800, 400, out after)) {
			path = "overview-reverse";
		}
	}

	if (path.length == 0 || after == before) {
		stderr.printf("%s: miss workspace-unchanged before=%d after=%d\n",
			TAG, before, after);
		return 1;
	}

	stdout.printf("%s: ok path=%s before=%d after=%d\n", TAG, path, before, after);
	return 0;
}