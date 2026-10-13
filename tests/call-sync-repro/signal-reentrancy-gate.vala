/**
 * Signal run-to-completion over a two-pipe client/server exchange.
 *
 * The client emits clicked. Its first handler makes a synchronous request.
 * Before replying, the server sends:
 *
 *  1. a blocking callback that the client must answer in-flow;
 *  2. a non-blocking before-update notification;
 *  3. the synchronous response.
 *
 * Current delivery dispatches before-update inside clicked and starts a drag.
 * The other modes model the four options in docs/plans/1.4-signal-reentrancy.md.
 */

private enum Mode
{
	CURRENT,
	LATER_DEPTH,
	SIGNAL_QUEUE,
	TRANSPORT_QUEUE,
	SERVER_DELAY,
}

private class Harness
{
	private const uint8 REQUEST = (uint8) 'R';
	private const uint8 RESPONSE = (uint8) 'S';
	private const uint8 BEFORE_UPDATE = (uint8) 'U';
	private const uint8 BLOCKING_CALLBACK = (uint8) 'B';
	private const uint8 CALLBACK_REPLY = (uint8) 'C';

	private Mode mode;
	private int client_read;
	private int client_write;
	private int server_read;
	private int server_write;
	private int signal_depth;
	private bool action_clicked;
	private bool drag_started;
	private bool deferred_before_update;
	private bool rescheduled_before_update;
	private bool blocking_callback_handled;
	private bool server_callback_replied;

	public Harness(Mode mode)
	{
		this.mode = mode;
	}

	private static bool write_byte(int fd, uint8 value)
	{
		uint8[] bytes = { value };
		return Posix.write(fd, bytes, bytes.length) == bytes.length;
	}

	private static bool read_byte(int fd, out uint8 value)
	{
		uint8[] bytes = new uint8[1];
		if (Posix.read(fd, bytes, bytes.length) != bytes.length) {
			value = 0;
			return false;
		}
		value = bytes[0];
		return true;
	}

	private void run_later()
	{
		if (this.mode == Mode.LATER_DEPTH && this.signal_depth > 1) {
			this.rescheduled_before_update = true;
			return;
		}
		if (this.action_clicked) {
			this.action_clicked = false;
			return;
		}
		this.drag_started = true;
	}

	private void emit_before_update()
	{
		this.signal_depth++;
		this.run_later();
		this.signal_depth--;
	}

	private void receive_before_update()
	{
		if ((this.mode == Mode.SIGNAL_QUEUE
				|| this.mode == Mode.TRANSPORT_QUEUE)
				&& this.signal_depth > 0) {
			this.deferred_before_update = true;
			return;
		}
		this.emit_before_update();
	}

	private bool receive_blocking_callback()
	{
		this.signal_depth++;
		this.blocking_callback_handled = true;
		var replied = Harness.write_byte(
			this.client_write, Harness.CALLBACK_REPLY);
		this.signal_depth--;
		return replied;
	}

	private bool call_sync()
	{
		if (!Harness.write_byte(this.client_write, Harness.REQUEST)) {
			return false;
		}
		while (true) {
			uint8 message;
			if (!Harness.read_byte(this.client_read, out message)) {
				return false;
			}
			switch (message) {
			case Harness.BLOCKING_CALLBACK:
				if (!this.receive_blocking_callback()) {
					return false;
				}
				break;
			case Harness.BEFORE_UPDATE:
				this.receive_before_update();
				break;
			case Harness.RESPONSE:
				return true;
			default:
				return false;
			}
		}
	}

	private bool run_server()
	{
		uint8 message;
		if (!Harness.read_byte(this.server_read, out message)
				|| message != Harness.REQUEST) {
			return false;
		}
		if (!Harness.write_byte(
				this.server_write, Harness.BLOCKING_CALLBACK)) {
			return false;
		}
		if (!Harness.read_byte(this.server_read, out message)
				|| message != Harness.CALLBACK_REPLY) {
			return false;
		}
		this.server_callback_replied = true;
		if (this.mode == Mode.SERVER_DELAY) {
			return Harness.write_byte(this.server_write, Harness.RESPONSE)
				&& Harness.write_byte(
					this.server_write, Harness.BEFORE_UPDATE);
		}
		return Harness.write_byte(this.server_write, Harness.BEFORE_UPDATE)
			&& Harness.write_byte(this.server_write, Harness.RESPONSE);
	}

	private bool run_clicked()
	{
		this.signal_depth++;
		var response = this.call_sync();
		if (response) {
			this.action_clicked = true;
		}
		this.signal_depth--;
		if (!response) {
			return false;
		}
		if (this.mode == Mode.SERVER_DELAY) {
			uint8 message;
			if (!Harness.read_byte(this.client_read, out message)
					|| message != Harness.BEFORE_UPDATE) {
				return false;
			}
			this.receive_before_update();
		}
		if (this.deferred_before_update) {
			this.deferred_before_update = false;
			this.emit_before_update();
		}
		if (this.rescheduled_before_update) {
			this.rescheduled_before_update = false;
			this.emit_before_update();
		}
		return true;
	}

	public bool run()
	{
		int client_to_server[2] = { -1, -1 };
		int server_to_client[2] = { -1, -1 };
		if (Posix.pipe(client_to_server) != 0
				|| Posix.pipe(server_to_client) != 0) {
			return false;
		}
		this.client_read = server_to_client[0];
		this.client_write = client_to_server[1];
		this.server_read = client_to_server[0];
		this.server_write = server_to_client[1];

		var server_ok = false;
		var server = new GLib.Thread<void*>("signal-server", () => {
			server_ok = this.run_server();
			return null;
		});
		var client_ok = this.run_clicked();
		server.join();

		Posix.close(client_to_server[0]);
		Posix.close(client_to_server[1]);
		Posix.close(server_to_client[0]);
		Posix.close(server_to_client[1]);

		return client_ok
			&& server_ok
			&& this.blocking_callback_handled
			&& this.server_callback_replied;
	}

	public bool dragged()
	{
		return this.drag_started;
	}
}

/**
 * Regression for the original {@code Meta.Laters.redraw_depth} guard.
 *
 * A later callback makes a synchronous request. The server sends a nested
 * before-update before its response. The nested frame must request a follow-up
 * pass; it must not invoke the active callback recursively.
 */
private class LaterReentryHarness
{
	private const uint8 REQUEST = (uint8) 'R';
	private const uint8 RESPONSE = (uint8) 'S';
	private const uint8 BEFORE_UPDATE = (uint8) 'U';

	private int client_read;
	private int client_write;
	private int server_read;
	private int server_write;
	private int redraw_depth;
	private int callback_depth;
	private int maximum_callback_depth;
	private int callback_count;
	private int followup_count;
	private bool redraw_pending;
	private bool entry_pending = true;

	private static bool write_byte(int fd, uint8 value)
	{
		uint8[] bytes = { value };
		return Posix.write(fd, bytes, bytes.length) == bytes.length;
	}

	private static bool read_byte(int fd, out uint8 value)
	{
		uint8[] bytes = new uint8[1];
		if (Posix.read(fd, bytes, bytes.length) != bytes.length) {
			value = 0;
			return false;
		}
		value = bytes[0];
		return true;
	}

	private bool call_sync()
	{
		if (!LaterReentryHarness.write_byte(
				this.client_write, LaterReentryHarness.REQUEST)) {
			return false;
		}
		while (true) {
			uint8 message;
			if (!LaterReentryHarness.read_byte(
					this.client_read, out message)) {
				return false;
			}
			if (message == LaterReentryHarness.BEFORE_UPDATE) {
				if (!this.run_before_redraw()) {
					return false;
				}
				continue;
			}
			return message == LaterReentryHarness.RESPONSE;
		}
	}

	private bool dispatch_before_redraw()
	{
		if (!this.entry_pending) {
			return true;
		}
		this.callback_depth++;
		this.callback_count++;
		if (this.callback_depth > this.maximum_callback_depth) {
			this.maximum_callback_depth = this.callback_depth;
		}
		var response = this.call_sync();
		this.callback_depth--;
		this.entry_pending = false;
		return response;
	}

	private bool run_before_redraw()
	{
		if (this.redraw_depth > 0) {
			this.redraw_pending = true;
			return true;
		}
		this.redraw_depth++;
		var dispatched = this.dispatch_before_redraw();
		if (dispatched && this.redraw_pending) {
			this.redraw_pending = false;
			this.followup_count++;
			dispatched = this.dispatch_before_redraw();
		}
		this.redraw_depth--;
		return dispatched;
	}

	private bool run_server()
	{
		uint8 message;
		if (!LaterReentryHarness.read_byte(
				this.server_read, out message)
				|| message != LaterReentryHarness.REQUEST) {
			return false;
		}
		return LaterReentryHarness.write_byte(
				this.server_write, LaterReentryHarness.BEFORE_UPDATE)
			&& LaterReentryHarness.write_byte(
				this.server_write, LaterReentryHarness.RESPONSE);
	}

	public bool run()
	{
		int client_to_server[2] = { -1, -1 };
		int server_to_client[2] = { -1, -1 };
		if (Posix.pipe(client_to_server) != 0
				|| Posix.pipe(server_to_client) != 0) {
			return false;
		}
		this.client_read = server_to_client[0];
		this.client_write = client_to_server[1];
		this.server_read = client_to_server[0];
		this.server_write = server_to_client[1];

		var server_ok = false;
		var server = new GLib.Thread<void*>("later-server", () => {
			server_ok = this.run_server();
			return null;
		});
		var client_ok = this.run_before_redraw();
		server.join();

		Posix.close(client_to_server[0]);
		Posix.close(client_to_server[1]);
		Posix.close(server_to_client[0]);
		Posix.close(server_to_client[1]);

		return client_ok
			&& server_ok
			&& this.callback_count == 1
			&& this.maximum_callback_depth == 1
			&& this.followup_count == 1
			&& !this.redraw_pending;
	}
}

private static bool parse_mode(string name, out Mode mode)
{
	switch (name) {
	case "current":
		mode = Mode.CURRENT;
		return true;
	case "later-depth":
		mode = Mode.LATER_DEPTH;
		return true;
	case "signal-queue":
		mode = Mode.SIGNAL_QUEUE;
		return true;
	case "transport-queue":
		mode = Mode.TRANSPORT_QUEUE;
		return true;
	case "server-delay":
		mode = Mode.SERVER_DELAY;
		return true;
	default:
		mode = Mode.CURRENT;
		return false;
	}
}

int main(string[] args)
{
	if (args.length != 2) {
		stderr.printf(
			"usage: %s current|later-depth|later-reentry|signal-queue|transport-queue|server-delay\n",
			args[0]);
		return 2;
	}
	if (args[1] == "later-reentry") {
		var later_harness = new LaterReentryHarness();
		if (!later_harness.run()) {
			stderr.printf(
				"FAIL later-reentry: active later callback was re-entered\n");
			return 1;
		}
		stderr.printf(
			"PASS later-reentry: nested frame ran as a follow-up pass\n");
		return 0;
	}
	Mode mode;
	if (!parse_mode(args[1], out mode)) {
		stderr.printf("unknown mode: %s\n", args[1]);
		return 2;
	}
	var harness = new Harness(mode);
	if (!harness.run()) {
		stderr.printf("FAIL %s: pipe exchange did not complete\n", args[1]);
		return 1;
	}
	if (harness.dragged()) {
		stderr.printf("FAIL %s: before-update started drag inside clicked\n",
			args[1]);
		return 1;
	}
	stderr.printf("PASS %s: clicked completed before before-update\n", args[1]);
	return 0;
}
