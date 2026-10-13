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
 * Proposal modes copy the Phase 5 rule from that plan. See
 * docs/signal-reentrancy.md before adding another reentrancy change.
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

/**
 * Distributed call stack over two pipes.
 *
 * The server opens one remote signal frame. The client handler
 * makes a nested synchronous RPC. That RPC synchronously emits a
 * causal signal. An unrelated source also becomes ready.
 *
 * Frame delivery runs the causal signal before the nested RPC
 * returns, and holds the unrelated signal until the outer frame
 * closes. Boolean and void signals share that schedule. Only the
 * completion byte differs: Y or K.
 *
 * Eager delivery lets the unrelated signal overtake the frame.
 * Defer-all holds the causal signal until the frame closes.
 *
 * Server mode uses the same client. The server decides.
 * A signal emitted by the nested call is sent at once.
 * A frame that becomes ready while a signal is open is held.
 * A frame that becomes ready with none open is sent at once.
 *
 * Proposal mode copies Connection.write from the Phase 5 blocks.
 * A one-way signal is held only when a wait is open and the
 * server is not inside the shell's call. Otherwise it is sent,
 * and the server waits for the reply.
 */
private enum StackPolicy
{
	FRAME,
	EAGER,
	DEFER,
	SERVER,
	PROPOSAL,
}

private enum ProposalWhen
{
	AFTER,
	DURING,
	NOREPLY,
}

private enum ClientRule
{
	NONE,
	EMIT_QUEUE,
	CALL_HOLD,
	LATER_SKIP,
}

private enum StackKind
{
	BOOLEAN,
	VOID,
}

private class StackHarness
{
	private StackPolicy policy;
	private StackKind kind;
	public ProposalWhen proposal_when;
	public ClientRule client_rule;
	public bool press_gap;
	public bool server_gap;
	public bool event_hold;
	private int queued_frames;
	private bool rescheduled_frame;
	public bool second_handler_ran;
	public bool frame_before_second;
	public bool drag_before_second;
	public bool drag_ran;
	private int emit_poll_depth;
	private bool in_dispatch;
	private uint8[] held_notifs = new uint8[8];
	private int held_count;
	public bool reply_timed_out;
	private int client_read;
	private int client_write;
	private int server_read;
	private int server_write;
	private int depth;
	private bool in_call;
	private int signals_open;
	private bool unrelated_waiting;
	private bool inside_nested_call;
	public bool caused_sent_inside_call;
	public bool unrelated_was_held;
	public bool immediate_when_idle;
	public int unrelated_sent;
	public bool causal_ran;
	public bool causal_nested;
	public int causal_depth;
	public bool unrelated_overtook;
	public bool unrelated_waited;
	public bool nested_completed;
	public uint8 reply_sent;

	public StackHarness(StackPolicy policy, StackKind kind)
	{
		this.policy = policy;
		this.kind = kind;
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

	private bool write_reply()
	{
		if (this.kind == StackKind.BOOLEAN) {
			this.reply_sent = (uint8) 'Y';
			return StackHarness.write_byte(this.client_write, this.reply_sent);
		}
		this.reply_sent = (uint8) 'K';
		return StackHarness.write_byte(this.client_write, this.reply_sent);
	}

	private bool read_reply()
	{
		uint8 token;
		if (!StackHarness.read_byte(this.server_read, out token)) {
			return false;
		}
		if (this.kind == StackKind.BOOLEAN) {
			return token == (uint8) 'Y';
		}
		return token == (uint8) 'K';
	}

	private static bool wait_fd(int fd, int timeout_ms)
	{
		Posix.pollfd slot = { fd, Posix.POLLIN, 0 };
		Posix.pollfd[] fds = { slot };
		return Posix.poll(fds, timeout_ms) > 0;
	}

	private bool read_reply_timed(int timeout_ms, out bool timed_out)
	{
		timed_out = false;
		if (!StackHarness.wait_fd(this.server_read, timeout_ms)) {
			timed_out = true;
			return false;
		}
		return this.read_reply();
	}

	private void hold_notif(uint8 message)
	{
		this.held_notifs[this.held_count] = message;
		this.held_count++;
	}

	private bool flush_held()
	{
		while (this.emit_poll_depth == 0 && this.held_count > 0) {
			var message = this.held_notifs[0];
			for (var i = 1; i < this.held_count; i++) {
				this.held_notifs[i - 1] = this.held_notifs[i];
			}
			this.held_count--;
			if (!this.send_and_wait(message)) {
				return false;
			}
		}
		return true;
	}

	private bool send_and_wait(uint8 message)
	{
		if (this.emit_poll_depth == 0 && message == (uint8) 'U') {
			this.immediate_when_idle = true;
		}
		if (!StackHarness.write_byte(this.server_write, message)) {
			return false;
		}
		if (message == (uint8) 'U') {
			this.unrelated_sent++;
		}
		if (message == (uint8) 'A') {
			this.caused_sent_inside_call = this.inside_nested_call
				&& this.signals_open > 0;
		}
		this.emit_poll_depth++;
		var replied = this.read_reply();
		this.emit_poll_depth--;
		if (!replied) {
			return false;
		}
		return this.flush_held();
	}

	private bool deliver_oneway(uint8 message)
	{
		if (this.emit_poll_depth > 0 && !this.in_dispatch) {
			this.hold_notif(message);
			if (message == (uint8) 'U') {
				this.unrelated_was_held = true;
			}
			return true;
		}
		return this.send_and_wait(message);
	}

	private bool accept_signal(uint8 message)
	{
		if (message == (uint8) 'A') {
			this.causal_ran = true;
			this.causal_depth = this.depth + 1;
			this.causal_nested = this.in_call && this.depth > 0;
		}
		if (message == (uint8) 'U') {
			if (this.depth > 0) {
				this.unrelated_overtook = true;
			}
			if (this.depth == 0 && !this.in_call) {
				this.unrelated_waited = true;
			}
		}
		this.depth++;
		var replied = this.write_reply();
		this.depth--;
		return replied;
	}

	private bool run_server()
	{
		if (!StackHarness.write_byte(this.server_write, (uint8) 'O')) {
			return false;
		}
		uint8 message;
		if (!StackHarness.read_byte(this.server_read, out message)
				|| message != (uint8) 'R') {
			return false;
		}
		switch (this.policy) {
		case StackPolicy.EAGER:
			if (!StackHarness.write_byte(this.server_write, (uint8) 'U')) {
				return false;
			}
			if (!this.read_reply()) {
				return false;
			}
			if (!StackHarness.write_byte(this.server_write, (uint8) 'A')) {
				return false;
			}
			if (!this.read_reply()) {
				return false;
			}
			if (!StackHarness.write_byte(this.server_write, (uint8) 'S')) {
				return false;
			}
			if (!this.read_reply()) {
				return false;
			}
			return StackHarness.write_byte(this.server_write, (uint8) 'D');

		case StackPolicy.SERVER:
			this.signals_open = 1;
			this.inside_nested_call = true;
			if (this.signals_open > 0) {
				this.unrelated_waiting = true;
				this.unrelated_was_held = true;
			}
			if (this.signals_open == 0) {
				if (!StackHarness.write_byte(this.server_write, (uint8) 'U')) {
					return false;
				}
				this.unrelated_sent++;
				this.immediate_when_idle = true;
				if (!this.read_reply()) {
					return false;
				}
			}
			if (!StackHarness.write_byte(this.server_write, (uint8) 'A')) {
				return false;
			}
			if (!this.read_reply()) {
				return false;
			}
			this.caused_sent_inside_call = this.inside_nested_call
				&& this.signals_open > 0;
			this.inside_nested_call = false;
			if (!StackHarness.write_byte(this.server_write, (uint8) 'S')) {
				return false;
			}
			if (!this.read_reply()) {
				return false;
			}
			this.signals_open = 0;
			if (this.unrelated_waiting) {
				this.unrelated_waiting = false;
				if (!StackHarness.write_byte(this.server_write, (uint8) 'U')) {
					return false;
				}
				this.unrelated_sent++;
				if (!this.read_reply()) {
					return false;
				}
			}
			if (this.signals_open > 0) {
				this.unrelated_waiting = true;
				this.unrelated_was_held = true;
			}
			if (this.signals_open == 0) {
				if (!StackHarness.write_byte(this.server_write, (uint8) 'U')) {
					return false;
				}
				this.unrelated_sent++;
				this.immediate_when_idle = true;
				if (!this.read_reply()) {
					return false;
				}
			}
			return StackHarness.write_byte(this.server_write, (uint8) 'D');

		case StackPolicy.PROPOSAL:
			this.emit_poll_depth = 1;
			this.signals_open = 1;
			this.in_dispatch = true;
			this.inside_nested_call = true;
			if (this.proposal_when == ProposalWhen.DURING) {
				if (!this.deliver_oneway((uint8) 'U')) {
					return false;
				}
			}
			if (!this.deliver_oneway((uint8) 'A')) {
				return false;
			}
			this.inside_nested_call = false;
			this.in_dispatch = false;
			if (this.proposal_when == ProposalWhen.AFTER) {
				if (!this.deliver_oneway((uint8) 'U')) {
					return false;
				}
			}
			if (!StackHarness.write_byte(this.server_write, (uint8) 'S')) {
				return false;
			}
			if (!this.read_reply()) {
				return false;
			}
			this.emit_poll_depth = 0;
			this.signals_open = 0;
			if (!this.flush_held()) {
				return false;
			}
			if (!this.deliver_oneway((uint8) 'U')) {
				return false;
			}
			return StackHarness.write_byte(this.server_write, (uint8) 'D');

		case StackPolicy.DEFER:
			if (!StackHarness.write_byte(this.server_write, (uint8) 'S')) {
				return false;
			}
			if (!this.read_reply()) {
				return false;
			}
			if (!StackHarness.write_byte(this.server_write, (uint8) 'A')) {
				return false;
			}
			if (!this.read_reply()) {
				return false;
			}
			if (!StackHarness.write_byte(this.server_write, (uint8) 'U')) {
				return false;
			}
			if (!this.read_reply()) {
				return false;
			}
			return StackHarness.write_byte(this.server_write, (uint8) 'D');

		default:
			break;
		}
		if (!StackHarness.write_byte(this.server_write, (uint8) 'A')) {
			return false;
		}
		if (!this.read_reply()) {
			return false;
		}
		if (!StackHarness.write_byte(this.server_write, (uint8) 'S')) {
			return false;
		}
		if (!this.read_reply()) {
			return false;
		}
		if (!StackHarness.write_byte(this.server_write, (uint8) 'U')) {
			return false;
		}
		if (!this.read_reply()) {
			return false;
		}
		return StackHarness.write_byte(this.server_write, (uint8) 'D');
	}

	private bool run_noreply_server()
	{
		this.emit_poll_depth = 0;
		this.in_dispatch = false;
		if (!StackHarness.write_byte(this.server_write, (uint8) 'U')) {
			return false;
		}
		var timed_out = false;
		if (this.read_reply_timed(200, out timed_out)) {
			return true;
		}
		this.reply_timed_out = timed_out;
		return timed_out;
	}

	private bool run_noreply_client()
	{
		uint8 message;
		if (!StackHarness.read_byte(this.client_read, out message)
				|| message != (uint8) 'U') {
			return false;
		}
		StackHarness.wait_fd(this.client_read, 500);
		return true;
	}

	private bool take_causal()
	{
		this.causal_ran = true;
		this.causal_depth = this.depth + 1;
		this.causal_nested = this.in_call && this.depth > 0;
		this.depth++;
		var replied = this.write_reply();
		this.depth--;
		return replied;
	}

	private void take_frame()
	{
		if (this.depth > 0) {
			this.unrelated_overtook = true;
		}
		if (this.depth == 0 && !this.in_call) {
			this.unrelated_waited = true;
		}
		if (!this.second_handler_ran) {
			this.frame_before_second = true;
		}
		if (this.client_rule == ClientRule.LATER_SKIP && this.depth > 0) {
			this.rescheduled_frame = true;
			return;
		}
		this.drag_ran = true;
		if (!this.second_handler_ran) {
			this.drag_before_second = true;
		}
	}

	private void flush_frames()
	{
		while (this.queued_frames > 0) {
			this.queued_frames--;
			this.take_frame();
		}
	}

	private void on_open_frame()
	{
		switch (this.client_rule) {
		case ClientRule.EMIT_QUEUE:
			if (this.depth > 0) {
				this.queued_frames++;
				return;
			}
			this.take_frame();
			return;

		case ClientRule.CALL_HOLD:
			if (this.in_call) {
				this.queued_frames++;
				return;
			}
			this.take_frame();
			return;

		case ClientRule.LATER_SKIP:
			this.take_frame();
			return;

		default:
			return;
		}
	}

	/**
	 * Long-press returns, then a frame, then clicked.
	 *
	 * The frame is one-way. No handler is running when
	 * it is sent. The click flag is set only by clicked.
	 */
	private bool run_press_gap_server()
	{
		if (!StackHarness.write_byte(this.server_write, (uint8) 'L')) {
			return false;
		}
		if (!this.read_reply()) {
			return false;
		}
		if (!StackHarness.write_byte(this.server_write, (uint8) 'U')) {
			return false;
		}
		if (!StackHarness.write_byte(this.server_write, (uint8) 'O')) {
			return false;
		}
		if (!this.read_reply()) {
			return false;
		}
		return StackHarness.write_byte(this.server_write, (uint8) 'D');
	}

	private bool run_press_gap_client()
	{
		uint8 message;
		if (!StackHarness.read_byte(this.client_read, out message)
				|| message != (uint8) 'L') {
			return false;
		}
		if (!this.write_reply()) {
			return false;
		}
		if (!StackHarness.read_byte(this.client_read, out message)
				|| message != (uint8) 'U') {
			return false;
		}
		this.on_open_frame();
		if (!StackHarness.read_byte(this.client_read, out message)
				|| message != (uint8) 'O') {
			return false;
		}
		this.depth = 1;
		this.second_handler_ran = true;
		this.depth = 0;
		if (this.client_rule == ClientRule.EMIT_QUEUE) {
			this.flush_frames();
		}
		if (!this.write_reply()) {
			return false;
		}
		if (!StackHarness.read_byte(this.client_read, out message)
				|| message != (uint8) 'D') {
			return false;
		}
		return true;
	}

	/**
	 * Phase 3 server rule on the guest order.
	 *
	 * A frame is held only while a signal is still
	 * open. long-press has already finished, so the
	 * frame is sent and waited for before clicked.
	 */
	private bool run_server_gap_server()
	{
		this.signals_open = 1;
		if (!StackHarness.write_byte(this.server_write, (uint8) 'L')) {
			return false;
		}
		if (!this.read_reply()) {
			return false;
		}
		this.signals_open = 0;
		if (this.signals_open > 0) {
			this.unrelated_waiting = true;
			this.unrelated_was_held = true;
		} else if (!StackHarness.write_byte(this.server_write, (uint8) 'U')
				|| !this.read_reply()) {
			return false;
		}
		this.signals_open = 1;
		if (!StackHarness.write_byte(this.server_write, (uint8) 'O')) {
			return false;
		}
		if (!this.read_reply()) {
			return false;
		}
		this.signals_open = 0;
		if (this.unrelated_waiting) {
			this.unrelated_waiting = false;
			if (!StackHarness.write_byte(this.server_write, (uint8) 'U')
					|| !this.read_reply()) {
				return false;
			}
		}
		return StackHarness.write_byte(this.server_write, (uint8) 'D');
	}

	private bool run_server_gap_client()
	{
		uint8 message;
		if (!StackHarness.read_byte(this.client_read, out message)
				|| message != (uint8) 'L') {
			return false;
		}
		if (!this.write_reply()) {
			return false;
		}
		while (true) {
			if (!StackHarness.read_byte(this.client_read, out message)) {
				return false;
			}
			if (message == (uint8) 'D') {
				return this.second_handler_ran;
			}
			if (message == (uint8) 'U') {
				this.take_frame();
				if (!this.write_reply()) {
					return false;
				}
				continue;
			}
			if (message == (uint8) 'O') {
				this.depth = 1;
				this.second_handler_ran = true;
				this.depth = 0;
				if (!this.write_reply()) {
					return false;
				}
				continue;
			}
			return false;
		}
	}

	/**
	 * One pointer event covers long-press and clicked.
	 *
	 * The frame becomes ready after long-press replies.
	 * It is not sent until clicked has replied. A signal
	 * caused by clicked's call is sent at once.
	 */
	private bool run_event_server()
	{
		if (!StackHarness.write_byte(this.server_write, (uint8) 'L')) {
			return false;
		}
		if (!this.read_reply()) {
			return false;
		}
		this.unrelated_waiting = true;
		this.unrelated_was_held = true;
		if (!StackHarness.write_byte(this.server_write, (uint8) 'O')) {
			return false;
		}
		uint8 message;
		if (!StackHarness.read_byte(this.server_read, out message)
				|| message != (uint8) 'R') {
			return false;
		}
		this.inside_nested_call = true;
		this.signals_open = 1;
		if (!StackHarness.write_byte(this.server_write, (uint8) 'A')) {
			return false;
		}
		if (!this.read_reply()) {
			return false;
		}
		this.caused_sent_inside_call = true;
		this.inside_nested_call = false;
		if (!StackHarness.write_byte(this.server_write, (uint8) 'S')) {
			return false;
		}
		if (!this.read_reply()) {
			return false;
		}
		this.signals_open = 0;
		this.unrelated_waiting = false;
		if (!StackHarness.write_byte(this.server_write, (uint8) 'U')) {
			return false;
		}
		return StackHarness.write_byte(this.server_write, (uint8) 'D');
	}

	private bool run_event_client()
	{
		uint8 message;
		if (!StackHarness.read_byte(this.client_read, out message)
				|| message != (uint8) 'L') {
			return false;
		}
		if (!this.write_reply()) {
			return false;
		}
		while (true) {
			if (!StackHarness.read_byte(this.client_read, out message)) {
				return false;
			}
			if (message == (uint8) 'D') {
				return this.second_handler_ran && this.causal_ran;
			}
			if (message == (uint8) 'U') {
				this.take_frame();
				continue;
			}
			if (message != (uint8) 'O') {
				return false;
			}
			this.depth = 1;
			this.in_call = true;
			if (!StackHarness.write_byte(this.client_write, (uint8) 'R')) {
				return false;
			}
			if (!StackHarness.read_byte(this.client_read, out message)
					|| message != (uint8) 'A' || !this.take_causal()) {
				return false;
			}
			if (!StackHarness.read_byte(this.client_read, out message)
					|| message != (uint8) 'S') {
				return false;
			}
			this.nested_completed = true;
			this.in_call = false;
			this.second_handler_ran = true;
			this.depth = 0;
			if (!this.write_reply()) {
				return false;
			}
		}
	}

	private bool run_open_server()
	{
		if (!StackHarness.write_byte(this.server_write, (uint8) 'O')) {
			return false;
		}
		uint8 message;
		if (!StackHarness.read_byte(this.server_read, out message)
				|| message != (uint8) 'R') {
			return false;
		}
		this.inside_nested_call = true;
		this.signals_open = 1;
		if (!StackHarness.write_byte(this.server_write, (uint8) 'A')) {
			return false;
		}
		if (!this.read_reply()) {
			return false;
		}
		this.caused_sent_inside_call = this.inside_nested_call;
		if (!StackHarness.write_byte(this.server_write, (uint8) 'U')) {
			return false;
		}
		this.unrelated_sent++;
		this.inside_nested_call = false;
		if (!StackHarness.write_byte(this.server_write, (uint8) 'S')) {
			return false;
		}
		if (!StackHarness.write_byte(this.server_write, (uint8) 'U')) {
			return false;
		}
		this.unrelated_sent++;
		if (!this.read_reply()) {
			return false;
		}
		return StackHarness.write_byte(this.server_write, (uint8) 'D');
	}

	private bool run_open_client()
	{
		uint8 message;
		if (!StackHarness.read_byte(this.client_read, out message)
				|| message != (uint8) 'O') {
			return false;
		}
		this.depth = 1;
		if (!StackHarness.write_byte(this.client_write, (uint8) 'R')) {
			return false;
		}
		this.in_call = true;
		if (!StackHarness.read_byte(this.client_read, out message)
				|| message != (uint8) 'A' || !this.take_causal()) {
			return false;
		}
		if (!StackHarness.read_byte(this.client_read, out message)
				|| message != (uint8) 'U') {
			return false;
		}
		this.on_open_frame();
		if (!StackHarness.read_byte(this.client_read, out message)
				|| message != (uint8) 'S') {
			return false;
		}
		this.nested_completed = this.depth > 0;
		this.in_call = false;
		if (this.client_rule == ClientRule.CALL_HOLD) {
			this.flush_frames();
		}
		this.second_handler_ran = true;
		if (!StackHarness.read_byte(this.client_read, out message)
				|| message != (uint8) 'U') {
			return false;
		}
		this.on_open_frame();
		if (this.client_rule == ClientRule.EMIT_QUEUE) {
			this.depth = 0;
			this.flush_frames();
		}
		if (this.client_rule == ClientRule.LATER_SKIP) {
			this.depth = 0;
			if (this.rescheduled_frame) {
				this.rescheduled_frame = false;
				this.drag_ran = true;
			}
		}
		if (this.client_rule == ClientRule.CALL_HOLD) {
			this.depth = 0;
		}
		if (!this.write_reply()) {
			return false;
		}
		if (!StackHarness.read_byte(this.client_read, out message)
				|| message != (uint8) 'D') {
			return false;
		}
		return this.causal_ran;
	}

	private bool drain_signal(uint8 message)
	{
		switch (message) {
		case (uint8) 'S':
			this.nested_completed = this.depth > 0;
			this.in_call = false;
			return true;

		case (uint8) 'A':
		case (uint8) 'U':
			return this.accept_signal(message);

		default:
			return false;
		}
	}

	private bool run_client()
	{
		uint8 message;
		if (!StackHarness.read_byte(this.client_read, out message)
				|| message != (uint8) 'O') {
			return false;
		}
		this.depth = 1;
		if (!StackHarness.write_byte(this.client_write, (uint8) 'R')) {
			return false;
		}
		this.in_call = true;
		while (this.in_call) {
			if (!StackHarness.read_byte(this.client_read, out message)) {
				return false;
			}
			if (!this.drain_signal(message)) {
				return false;
			}
		}
		this.depth = 0;
		if (!this.write_reply()) {
			return false;
		}
		while (true) {
			if (!StackHarness.read_byte(this.client_read, out message)) {
				return false;
			}
			if (message == (uint8) 'D') {
				return this.causal_ran;
			}
			if (!this.drain_signal(message)) {
				return false;
			}
		}
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
		var client_ok = false;
		if (this.policy == StackPolicy.PROPOSAL
				&& this.proposal_when == ProposalWhen.NOREPLY) {
			var server = new GLib.Thread<void*>("stack-server", () => {
				server_ok = this.run_noreply_server();
				return null;
			});
			client_ok = this.run_noreply_client();
			server.join();
		} else if (this.event_hold) {
			var server = new GLib.Thread<void*>("stack-server", () => {
				server_ok = this.run_event_server();
				return null;
			});
			client_ok = this.run_event_client();
			server.join();
		} else if (this.server_gap) {
			var server = new GLib.Thread<void*>("stack-server", () => {
				server_ok = this.run_server_gap_server();
				return null;
			});
			client_ok = this.run_server_gap_client();
			server.join();
		} else if (this.press_gap) {
			var server = new GLib.Thread<void*>("stack-server", () => {
				server_ok = this.run_press_gap_server();
				return null;
			});
			client_ok = this.run_press_gap_client();
			server.join();
		} else if (this.client_rule != ClientRule.NONE) {
			var server = new GLib.Thread<void*>("stack-server", () => {
				server_ok = this.run_open_server();
				return null;
			});
			client_ok = this.run_open_client();
			server.join();
		} else {
			var server = new GLib.Thread<void*>("stack-server", () => {
				server_ok = this.run_server();
				return null;
			});
			client_ok = this.run_client();
			server.join();
		}

		Posix.close(client_to_server[0]);
		Posix.close(client_to_server[1]);
		Posix.close(server_to_client[0]);
		Posix.close(server_to_client[1]);

		if (this.press_gap || this.server_gap || this.event_hold) {
			return client_ok && server_ok;
		}
		if (this.policy == StackPolicy.PROPOSAL
				&& this.proposal_when == ProposalWhen.NOREPLY) {
			return client_ok && server_ok;
		}
		return client_ok && server_ok && this.nested_completed;
	}

	public bool held()
	{
		if (!this.causal_ran || !this.causal_nested) {
			return false;
		}
		if (this.causal_depth != 2) {
			return false;
		}
		if (!this.nested_completed || this.unrelated_overtook) {
			return false;
		}
		return this.unrelated_waited;
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
			"usage: %s current|later-depth|later-reentry|signal-queue|transport-queue|server-delay|stack-bool|stack-void|stack|stack-eager|stack-defer|server-bool|server-void|server|proposal-after|proposal-during|proposal-noreply|emit-queue|call-hold|later-skip|press-gap|server-gap|event\n",
			args[0]);
		return 2;
	}
	if (args[1] == "stack-bool" || args[1] == "stack-void") {
		var kind = StackKind.VOID;
		var reply = (uint8) 'K';
		if (args[1] == "stack-bool") {
			kind = StackKind.BOOLEAN;
			reply = (uint8) 'Y';
		}
		var harness = new StackHarness(StackPolicy.FRAME, kind);
		if (!harness.run() || !harness.held() || harness.reply_sent != reply) {
			stderr.printf(
				"FAIL %s: remote frame did not hold the unrelated signal\n",
				args[1]);
			return 1;
		}
		stderr.printf(
			"PASS %s: nested rpc completed, causal signal nested, unrelated waited\n",
			args[1]);
		return 0;
	}
	if (args[1] == "stack") {
		var bool_harness = new StackHarness(StackPolicy.FRAME, StackKind.BOOLEAN);
		var void_harness = new StackHarness(StackPolicy.FRAME, StackKind.VOID);
		if (!bool_harness.run() || !void_harness.run()
				|| !bool_harness.held() || !void_harness.held()
				|| bool_harness.causal_depth != void_harness.causal_depth
				|| bool_harness.reply_sent == void_harness.reply_sent) {
			stderr.printf(
				"FAIL stack: boolean and void schedules diverged\n");
			return 1;
		}
		stderr.printf(
			"PASS stack: boolean and void differ only in reply payload\n");
		return 0;
	}
	if (args[1] == "server-bool" || args[1] == "server-void") {
		var kind = StackKind.VOID;
		var reply = (uint8) 'K';
		if (args[1] == "server-bool") {
			kind = StackKind.BOOLEAN;
			reply = (uint8) 'Y';
		}
		var server_harness = new StackHarness(StackPolicy.SERVER, kind);
		if (!server_harness.run() || !server_harness.held()
				|| server_harness.reply_sent != reply
				|| !server_harness.caused_sent_inside_call
				|| !server_harness.unrelated_was_held
				|| !server_harness.immediate_when_idle
				|| server_harness.unrelated_sent != 2) {
			stderr.printf(
				"FAIL %s: server did not keep the open signal ahead of a ready frame\n",
				args[1]);
			return 1;
		}
		stderr.printf(
			"PASS %s: server sent the caused signal at once and held the ready frame\n",
			args[1]);
		return 0;
	}
	if (args[1] == "server") {
		var server_bool = new StackHarness(StackPolicy.SERVER, StackKind.BOOLEAN);
		var server_void = new StackHarness(StackPolicy.SERVER, StackKind.VOID);
		if (!server_bool.run() || !server_void.run()
				|| !server_bool.held() || !server_void.held()
				|| !server_bool.caused_sent_inside_call
				|| !server_void.caused_sent_inside_call
				|| !server_bool.unrelated_was_held
				|| !server_void.unrelated_was_held
				|| !server_bool.immediate_when_idle
				|| !server_void.immediate_when_idle
				|| server_bool.unrelated_sent != 2
				|| server_void.unrelated_sent != 2
				|| server_bool.reply_sent == server_void.reply_sent) {
			stderr.printf(
				"FAIL server: boolean and void server decisions diverged\n");
			return 1;
		}
		stderr.printf(
			"PASS server: boolean and void use the same server decision\n");
		return 0;
	}
	if (args[1] == "proposal-after") {
		var proposal_bool = new StackHarness(StackPolicy.PROPOSAL,
			StackKind.BOOLEAN);
		var proposal_void = new StackHarness(StackPolicy.PROPOSAL,
			StackKind.VOID);
		proposal_bool.proposal_when = ProposalWhen.AFTER;
		proposal_void.proposal_when = ProposalWhen.AFTER;
		if (!proposal_bool.run() || !proposal_void.run()
				|| !proposal_bool.held() || !proposal_void.held()
				|| !proposal_bool.caused_sent_inside_call
				|| !proposal_void.caused_sent_inside_call
				|| !proposal_bool.unrelated_was_held
				|| !proposal_void.unrelated_was_held
				|| !proposal_bool.immediate_when_idle
				|| !proposal_void.immediate_when_idle
				|| proposal_bool.unrelated_sent != 2
				|| proposal_void.unrelated_sent != 2
				|| proposal_bool.reply_sent == proposal_void.reply_sent) {
			stderr.printf(
				"FAIL proposal-after: frame after the call was not held\n");
			return 1;
		}
		stderr.printf(
			"PASS proposal-after: frame after the nested call was held\n");
		return 0;
	}
	if (args[1] == "proposal-during") {
		var during = new StackHarness(StackPolicy.PROPOSAL, StackKind.VOID);
		during.proposal_when = ProposalWhen.DURING;
		if (!during.run() || !during.causal_nested
				|| during.causal_depth != 2
				|| !during.caused_sent_inside_call) {
			stderr.printf(
				"FAIL proposal-during: pipe exchange did not complete\n");
			return 1;
		}
		if (during.unrelated_overtook) {
			stderr.printf(
				"FAIL proposal-during: frame inside the call was sent at once\n");
			return 1;
		}
		stderr.printf(
			"PASS proposal-during: frame inside the call was held\n");
		return 0;
	}
	if (args[1] == "proposal-noreply") {
		var silent = new StackHarness(StackPolicy.PROPOSAL, StackKind.VOID);
		silent.proposal_when = ProposalWhen.NOREPLY;
		if (!silent.run()) {
			stderr.printf(
				"FAIL proposal-noreply: pipe exchange did not complete\n");
			return 1;
		}
		if (silent.reply_timed_out) {
			stderr.printf(
				"FAIL proposal-noreply: server waited for a reply the client never sent\n");
			return 1;
		}
		stderr.printf(
			"PASS proposal-noreply: server did not wait for a missing reply\n");
		return 0;
	}
	if (args[1] == "emit-queue") {
		var queue_bool = new StackHarness(StackPolicy.FRAME, StackKind.BOOLEAN);
		var queue_void = new StackHarness(StackPolicy.FRAME, StackKind.VOID);
		queue_bool.client_rule = ClientRule.EMIT_QUEUE;
		queue_void.client_rule = ClientRule.EMIT_QUEUE;
		if (!queue_bool.run() || !queue_void.run()
				|| !queue_bool.held() || !queue_void.held()
				|| !queue_bool.second_handler_ran
				|| !queue_void.second_handler_ran
				|| queue_bool.frame_before_second
				|| queue_void.frame_before_second
				|| queue_bool.drag_before_second
				|| queue_void.drag_before_second
				|| !queue_bool.drag_ran || !queue_void.drag_ran
				|| queue_bool.reply_sent == queue_void.reply_sent) {
			stderr.printf(
				"FAIL emit-queue: frame ran before the click handler returned\n");
			return 1;
		}
		stderr.printf(
			"PASS emit-queue: frame waited until the click handler returned\n");
		return 0;
	}
	if (args[1] == "press-gap") {
		var gap = new StackHarness(StackPolicy.FRAME, StackKind.VOID);
		gap.client_rule = ClientRule.EMIT_QUEUE;
		gap.press_gap = true;
		if (!gap.run() || !gap.second_handler_ran) {
			stderr.printf(
				"FAIL press-gap: pipe exchange did not complete\n");
			return 1;
		}
		if (gap.drag_before_second) {
			stderr.printf(
				"FAIL press-gap: frame between long-press and clicked started the drag\n");
			return 1;
		}
		stderr.printf(
			"PASS press-gap: frame waited until clicked set the flag\n");
		return 0;
	}
	if (args[1] == "event") {
		var held = new StackHarness(StackPolicy.SERVER, StackKind.VOID);
		held.event_hold = true;
		if (!held.run() || !held.second_handler_ran || !held.causal_nested
				|| !held.caused_sent_inside_call || !held.unrelated_was_held
				|| !held.drag_ran) {
			stderr.printf(
				"FAIL event: pipe exchange did not complete\n");
			return 1;
		}
		if (held.drag_before_second) {
			stderr.printf(
				"FAIL event: frame ran before clicked set the flag\n");
			return 1;
		}
		stderr.printf(
			"PASS event: frame waited until clicked set the flag\n");
		return 0;
	}
	if (args[1] == "server-gap") {
		var gap = new StackHarness(StackPolicy.SERVER, StackKind.VOID);
		gap.server_gap = true;
		if (!gap.run() || !gap.second_handler_ran) {
			stderr.printf(
				"FAIL server-gap: pipe exchange did not complete\n");
			return 1;
		}
		if (gap.drag_before_second) {
			stderr.printf(
				"FAIL server-gap: frame between long-press and clicked started the drag\n");
			return 1;
		}
		stderr.printf(
			"PASS server-gap: frame waited until clicked set the flag\n");
		return 0;
	}
	if (args[1] == "call-hold") {
		var hold = new StackHarness(StackPolicy.FRAME, StackKind.VOID);
		hold.client_rule = ClientRule.CALL_HOLD;
		if (!hold.run() || !hold.causal_nested || hold.causal_depth != 2
				|| !hold.second_handler_ran) {
			stderr.printf(
				"FAIL call-hold: pipe exchange did not complete\n");
			return 1;
		}
		if (hold.unrelated_overtook && hold.frame_before_second) {
			stderr.printf(
				"FAIL call-hold: frame ran before the click finished\n");
			return 1;
		}
		stderr.printf(
			"PASS call-hold: frame waited until the click finished\n");
		return 0;
	}
	if (args[1] == "later-skip") {
		var skip = new StackHarness(StackPolicy.FRAME, StackKind.VOID);
		skip.client_rule = ClientRule.LATER_SKIP;
		if (!skip.run() || !skip.causal_nested || skip.causal_depth != 2
				|| !skip.second_handler_ran) {
			stderr.printf(
				"FAIL later-skip: pipe exchange did not complete\n");
			return 1;
		}
		if (skip.unrelated_overtook && !skip.drag_before_second
				&& skip.drag_ran) {
			stderr.printf(
				"FAIL later-skip: frame signal ran inside the open click\n");
			return 1;
		}
		stderr.printf(
			"PASS later-skip: frame waited until the click finished\n");
		return 0;
	}
	if (args[1] == "stack-eager") {
		var harness = new StackHarness(StackPolicy.EAGER, StackKind.BOOLEAN);
		if (!harness.run() || !harness.unrelated_overtook
				|| !harness.causal_nested || harness.causal_depth != 2) {
			stderr.printf(
				"FAIL stack-eager: pipe exchange did not complete\n");
			return 1;
		}
		stderr.printf(
			"FAIL stack-eager: unrelated signal overtook the open remote frame\n");
		return 1;
	}
	if (args[1] == "stack-defer") {
		var harness = new StackHarness(StackPolicy.DEFER, StackKind.BOOLEAN);
		if (!harness.run() || harness.causal_nested || !harness.causal_ran
				|| !harness.unrelated_waited) {
			stderr.printf(
				"FAIL stack-defer: pipe exchange did not complete\n");
			return 1;
		}
		stderr.printf(
			"FAIL stack-defer: causal signal waited until the outer frame closed\n");
		return 1;
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
