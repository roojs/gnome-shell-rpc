/**
 * Gate: ''meta_wayland_client_new_subprocess'' passes the child end of
 * its Wayland socketpair to ''g_subprocess_launcher_take_fd''.
 *
 * Holding ''GLib.SubprocessLauncher'' on the leased ''WaylandClient''
 * row keeps that fd open in ''gsr-server'' after ''force_exit()''
 * kills the child, so ''wl_client'' never sees ''G_IO_HUP'' and the
 * window stays in ''list_all_windows''. Closing the launcher after
 * spawn releases the parent copy, and ''wait_async'' without a prior
 * ''get_if_exited()'' avoids GLib's ''pid == 0'' critical.
 *
 * {{{
 * meson compile -C build wayland-client-launcher-fd-gate
 * timeout 5 ./build/tests/call-sync-repro/wayland-client-launcher-fd-gate current
 * timeout 5 ./build/tests/call-sync-repro/wayland-client-launcher-fd-gate fixed
 * }}}
 */

int main(string[] args)
{
	var mode = "current";
	if (args.length >= 2) {
		mode = args[1];
	}
	if (mode != "current" && mode != "fixed") {
		GLib.stderr.printf("FAIL wayland-client-launcher-fd-gate: mode %s\n",
			mode);
		return 2;
	}

	var criticals = 0;
	GLib.Log.set_handler("GLib-GIO",
		GLib.LogLevelFlags.LEVEL_CRITICAL,
		(dom, lvl, msg) => {
			criticals++;
		});

	var pair = new int[2];
	if (Posix.socketpair(Posix.AF_UNIX, Posix.SOCK_STREAM, 0, pair) != 0) {
		GLib.stderr.printf("FAIL wayland-client-launcher-fd-gate: socketpair\n");
		return 2;
	}

	var launcher = new GLib.SubprocessLauncher(GLib.SubprocessFlags.NONE);
	launcher.take_fd(pair[1], 3);

	GLib.Subprocess proc;
	try {
		proc = launcher.spawnv({ "sleep", "30" });
	} catch (GLib.Error e) {
		Posix.close(pair[0]);
		GLib.stderr.printf("FAIL wayland-client-launcher-fd-gate: %s\n",
			e.message);
		return 2;
	}

	if (mode == "fixed") {
		launcher.close();
	}

	var loop = new GLib.MainLoop();
	if (mode == "current") {
		if (!proc.get_if_exited()) {
			proc.wait_async.begin(null, (obj, res) => {
				try {
					proc.wait_async.end(res);
				} catch (GLib.Error e) {
				}
				loop.quit();
			});
		}
		if (proc.get_if_exited()) {
			loop.quit();
		}
	}
	if (mode == "fixed") {
		proc.wait_async.begin(null, (obj, res) => {
			try {
				proc.wait_async.end(res);
			} catch (GLib.Error e) {
			}
			loop.quit();
		});
	}

	proc.force_exit();
	loop.run();

	var poll_fd = GLib.PollFD() {
		fd = pair[0],
		events = GLib.IOCondition.IN | GLib.IOCondition.HUP | GLib.IOCondition.ERR,
	};
	var fds = new GLib.PollFD[] { poll_fd };
	var ready = GLib.poll(fds, 100);
	var hup = ready > 0 && (fds[0].revents & GLib.IOCondition.HUP) != 0;

	Posix.close(pair[0]);
	launcher.close();

	if (!hup || criticals > 0) {
		GLib.stderr.printf(
			"FAIL wayland-client-launcher-fd-gate %s: hup=%s criticals=%d\n",
			mode, hup.to_string(), criticals);
		return 1;
	}
	GLib.stderr.printf(
		"PASS wayland-client-launcher-fd-gate %s: hup=%s criticals=%d\n",
		mode, hup.to_string(), criticals);
	return 0;
}
