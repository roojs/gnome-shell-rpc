/**
 * Gate: Live.Hook.emit on a connection that has already stopped must
 * return, not wait forever.
 *
 * Live shape: the shell client exits; gsr-server stops its connection.
 * A Clutter vfunc trampoline (layout manager allocate, constraint update)
 * still holds its Hook row and fires on the next relayout. Hook.emit
 * resets replied, write() is a no-op on the closed channel, callbacks
 * is cleared, so nothing ever completes the frame. mutter hangs in
 * emit_wait_poll.
 *
 * Base OLLMrpc.Transport.Connection only; no consumer subclass.
 *
 *   meson compile -C build hook-emit-after-stop-gate
 *   timeout 5 ./build/tests/call-sync-repro/hook-emit-after-stop-gate
 *
 * PASS → emit returns after stop.
 * FAIL → watchdog fired while emit was still waiting.
 */

int main(string[] args)
{
	var path = "/tmp/gsr-hook-emit-after-stop-gate-%d.sock".printf(
		(int) (GLib.get_monotonic_time() & 0x7fffffff));
	GLib.FileUtils.unlink(path);

	GLib.SocketConnection peer;
	GLib.SocketConnection accepted;
	try {
		var listener = new GLib.SocketListener();
		var addr = new GLib.UnixSocketAddress(path);
		listener.add_address(addr, GLib.SocketType.STREAM,
			GLib.SocketProtocol.DEFAULT, null, null);
		peer = new GLib.SocketClient().connect(addr);
		accepted = listener.accept();
	} catch (GLib.Error e) {
		stderr.printf("FAIL hook-emit-after-stop-gate: socket %s\n", e.message);
		return 2;
	}
	GLib.FileUtils.unlink(path);

	var conn = new OLLMrpc.Transport.Connection(accepted);
	conn.start();

	var hook = new OLLMrpc.Live.Hook() {
		connection = conn,
		id = conn.next_handle,
	};
	conn.next_handle++;
	conn.callbacks.set(hook.id, hook);

	conn.stop();
	stderr.printf("gate: connection stopped, emitting on held hook\n");
	stderr.flush();

	GLib.Timeout.add(2000, () => {
		stderr.printf(
			"FAIL hook-emit-after-stop-gate: Hook.emit still waiting 2s after "
			+ "the connection stopped.\n"
		);
		stderr.flush();
		GLib.Process.exit(1);
	});

	hook.emit(new Gee.ArrayList<GLib.Value?>());

	stderr.printf("PASS hook-emit-after-stop-gate reply_args=%d\n", hook.reply_args.size);
	peer.close();
	return 0;
}
