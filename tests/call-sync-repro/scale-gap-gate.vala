/**
 * Scale timeline removed while startDrag is still inside its handler.
 *
 * dnd.js eases scale-x for 250ms, then calls get_transition('scale-x') and
 * connects new-frame. drag-begin has already taken the grab. On the RPC path
 * before-update is one-way, so the frame clock runs in the gaps while that
 * handler has not returned. A gap longer than 250ms finishes the timeline,
 * stopped is sent without waiting, and the second read is null.
 *
 * current is that split. in-process is the single-process clock, not a
 * strategy. The other modes are strategies tried on this gate. None of them
 * link product source.
 *
 * pause-on-ease pauses when ease returns and starts when the handler
 * returns. pause-on-get pauses only after a successful get, so a gap before
 * that get still wins (ease-gap). start-on-frame waits for the new-frame
 * subscribe dnd.js already does; frame-plain is an ordinary ease that never
 * subscribes, so it never starts. start-on-stopped starts at the subscribe
 * get_transition already does, which is too early. hold-until-click never
 * releases, because a drag has no clicked. inhibit-drag keeps the timeline
 * paused for as long as the grab is held, so the scale never runs.
 */

private enum Policy
{
	SPLIT,
	IN_PROCESS,
	PAUSE_ON_EASE,
	PAUSE_PLAIN,
	PAUSE_ON_GET,
	EASE_GAP,
	START_ON_FRAME,
	FRAME_PLAIN,
	START_ON_STOPPED,
	HOLD_CLICK,
	INHIBIT_DRAG,
}

private class Harness
{
	private const uint8 EASE = (uint8) 'E';
	private const uint8 GET = (uint8) 'G';
	private const uint8 QUIET = (uint8) 'Q';
	private const uint8 HANDLER_DONE = (uint8) 'H';
	private const uint8 END = (uint8) 'X';
	private const uint8 PAUSE = (uint8) 'A';
	private const uint8 START = (uint8) 'U';
	private const uint8 NEW_FRAME = (uint8) 'F';
	private const uint8 SUBSCRIBE_STOPPED = (uint8) 'Z';
	private const uint8 PRESENT = (uint8) 'P';
	private const uint8 ABSENT = (uint8) 'N';
	private const uint8 STOPPED = (uint8) 'T';
	private const uint8 DONE = (uint8) 'D';
	private const uint8 ACK = (uint8) 'K';
	private const int DURATION = 250;
	private const int GAP = 400;

	private Policy policy;
	private int client_read;
	private int client_write;
	private int server_read;
	private int server_write;
	private bool handler_open;
	private bool timeline_present;
	private bool paused;
	private int elapsed;
	private int pending_gap;
	private int get_count;
	private bool server_ok;
	private bool client_ok;

	public bool grab_held;
	public bool first_present;
	public bool second_present;
	public bool saw_stopped;
	public bool stopped_while_open;
	public bool new_frame_connected;
	public int scale_milli;
	public int scale_at_second;

	public Harness(Policy policy)
	{
		this.policy = policy;
		this.handler_open = true;
		this.scale_milli = 1000;
		this.scale_at_second = 1000;
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

	private bool finishes_on_handler()
	{
		return this.policy == Policy.SPLIT
			|| this.policy == Policy.IN_PROCESS;
	}

	private bool apply_gap(int gap)
	{
		if (this.policy == Policy.IN_PROCESS && this.handler_open) {
			this.pending_gap += gap;
			return true;
		}
		if (this.paused || !this.timeline_present) {
			return true;
		}
		this.elapsed += gap;
		if (this.elapsed < Harness.DURATION) {
			this.scale_milli = 1000
				- ((1000 - 500) * this.elapsed / Harness.DURATION);
			return true;
		}
		this.elapsed = Harness.DURATION;
		this.scale_milli = 500;
		this.timeline_present = false;
		this.stopped_while_open = this.handler_open;
		return Harness.write_byte(this.server_write, Harness.STOPPED);
	}

	private bool run_server()
	{
		while (true) {
			uint8 message;
			if (!Harness.read_byte(this.server_read, out message)) {
				return false;
			}
			if (message == Harness.EASE) {
				this.timeline_present = true;
				this.elapsed = 0;
				this.scale_milli = 1000;
				this.paused = this.policy == Policy.START_ON_FRAME
					|| this.policy == Policy.FRAME_PLAIN
					|| this.policy == Policy.START_ON_STOPPED
					|| this.policy == Policy.HOLD_CLICK
					|| this.policy == Policy.INHIBIT_DRAG;
				if (!Harness.write_byte(this.server_write, Harness.PRESENT)) {
					return false;
				}
				continue;
			}
			if (message == Harness.GET) {
				this.get_count++;
				if (this.get_count == 2) {
					this.scale_at_second = this.scale_milli;
				}
				var reply = Harness.ABSENT;
				if (this.timeline_present) {
					reply = Harness.PRESENT;
				}
				if (!Harness.write_byte(this.server_write, reply)) {
					return false;
				}
				continue;
			}
			if (message == Harness.QUIET) {
				uint8 hi = 0;
				uint8 lo = 0;
				if (!Harness.read_byte(this.server_read, out hi)
						|| !Harness.read_byte(this.server_read, out lo)) {
					return false;
				}
				if (!this.apply_gap(hi * 256 + lo)) {
					return false;
				}
				continue;
			}
			if (message == Harness.PAUSE) {
				this.paused = true;
				if (!Harness.write_byte(this.server_write, Harness.ACK)) {
					return false;
				}
				continue;
			}
			if (message == Harness.START
					|| message == Harness.NEW_FRAME
					|| message == Harness.SUBSCRIBE_STOPPED) {
				if (message == Harness.NEW_FRAME
						&& this.policy != Policy.START_ON_FRAME) {
					if (!Harness.write_byte(this.server_write, Harness.ACK)) {
						return false;
					}
					continue;
				}
				if (message == Harness.SUBSCRIBE_STOPPED
						&& this.policy != Policy.START_ON_STOPPED) {
					if (!Harness.write_byte(this.server_write, Harness.ACK)) {
						return false;
					}
					continue;
				}
				if (this.policy == Policy.HOLD_CLICK
						|| this.policy == Policy.INHIBIT_DRAG) {
					if (!Harness.write_byte(this.server_write, Harness.ACK)) {
						return false;
					}
					continue;
				}
				this.paused = false;
				if (!Harness.write_byte(this.server_write, Harness.ACK)) {
					return false;
				}
				continue;
			}
			if (message == Harness.HANDLER_DONE) {
				this.handler_open = false;
				if (this.finishes_on_handler()) {
					if (!this.apply_gap(this.pending_gap)) {
						return false;
					}
					return Harness.write_byte(this.server_write, Harness.DONE);
				}
				if (!Harness.write_byte(this.server_write, Harness.DONE)) {
					return false;
				}
				continue;
			}
			if (message == Harness.END) {
				return true;
			}
			return false;
		}
	}

	private bool read_reply(out uint8 reply)
	{
		uint8 message;
		if (!Harness.read_byte(this.client_read, out message)) {
			reply = 0;
			return false;
		}
		if (message == Harness.STOPPED) {
			this.saw_stopped = true;
			if (!Harness.read_byte(this.client_read, out message)) {
				reply = 0;
				return false;
			}
		}
		reply = message;
		return true;
	}

	private bool ease()
	{
		uint8 reply;
		if (!Harness.write_byte(this.client_write, Harness.EASE)) {
			return false;
		}
		if (!Harness.read_byte(this.client_read, out reply)
				|| reply != Harness.PRESENT) {
			return false;
		}
		return true;
	}

	private bool quiet(int gap)
	{
		uint8 hi = (uint8) (gap / 256);
		uint8 lo = (uint8) (gap % 256);
		uint8[] bytes = { Harness.QUIET, hi, lo };
		return Posix.write(this.client_write, bytes, bytes.length) == bytes.length;
	}

	private bool get_scale(bool first)
	{
		uint8 reply;
		if (!Harness.write_byte(this.client_write, Harness.GET)) {
			return false;
		}
		if (!this.read_reply(out reply)) {
			return false;
		}
		if (first) {
			this.first_present = reply == Harness.PRESENT;
		} else {
			this.second_present = reply == Harness.PRESENT;
		}
		return true;
	}

	private bool ack(uint8 op)
	{
		uint8 reply;
		if (!Harness.write_byte(this.client_write, op)) {
			return false;
		}
		if (!this.read_reply(out reply) || reply != Harness.ACK) {
			return false;
		}
		return true;
	}

	private bool handler_done()
	{
		uint8 reply;
		if (!Harness.write_byte(this.client_write, Harness.HANDLER_DONE)) {
			return false;
		}
		if (!this.read_reply(out reply) || reply != Harness.DONE) {
			return false;
		}
		return true;
	}

	private bool end_turn()
	{
		return Harness.write_byte(this.client_write, Harness.END);
	}

	private bool play_after_handler()
	{
		if (!this.ack(Harness.START)) {
			return false;
		}
		if (!this.handler_done()) {
			return false;
		}
		if (!this.quiet(Harness.DURATION)) {
			return false;
		}
		if (!this.end_turn()) {
			return false;
		}
		uint8 message;
		if (!Harness.read_byte(this.client_read, out message)
				|| message != Harness.STOPPED) {
			return false;
		}
		this.saw_stopped = true;
		return true;
	}

	private bool close_without_play()
	{
		if (!this.handler_done()) {
			return false;
		}
		return this.end_turn();
	}

	private bool script_split()
	{
		this.grab_held = true;
		if (!this.ease()) {
			return false;
		}
		if (!this.get_scale(true)) {
			return false;
		}
		if (!this.quiet(Harness.GAP)) {
			return false;
		}
		if (!this.get_scale(false)) {
			return false;
		}
		if (this.second_present) {
			this.new_frame_connected = true;
		}
		if (!Harness.write_byte(this.client_write, Harness.HANDLER_DONE)) {
			return false;
		}
		uint8 message;
		if (!Harness.read_byte(this.client_read, out message)) {
			return false;
		}
		if (message == Harness.STOPPED) {
			this.saw_stopped = true;
			if (!Harness.read_byte(this.client_read, out message)) {
				return false;
			}
		}
		return message == Harness.DONE;
	}

	private bool script_pause_ease()
	{
		this.grab_held = true;
		if (!this.ease() || !this.ack(Harness.PAUSE)) {
			return false;
		}
		if (!this.quiet(Harness.GAP) || !this.get_scale(true)) {
			return false;
		}
		if (!this.quiet(Harness.GAP) || !this.get_scale(false)) {
			return false;
		}
		if (this.second_present && this.policy == Policy.PAUSE_ON_EASE) {
			this.new_frame_connected = true;
		}
		return this.play_after_handler();
	}

	private bool script_pause_get()
	{
		this.grab_held = true;
		if (!this.ease() || !this.get_scale(true)) {
			return false;
		}
		if (this.first_present && !this.ack(Harness.PAUSE)) {
			return false;
		}
		if (!this.quiet(Harness.GAP) || !this.get_scale(false)) {
			return false;
		}
		if (this.second_present) {
			this.new_frame_connected = true;
		}
		if (!this.second_present) {
			return this.close_without_play();
		}
		return this.play_after_handler();
	}

	private bool script_ease_gap()
	{
		this.grab_held = true;
		if (!this.ease() || !this.quiet(Harness.GAP)) {
			return false;
		}
		if (!this.get_scale(true)) {
			return false;
		}
		return this.close_without_play();
	}

	private bool script_frame()
	{
		this.grab_held = true;
		if (!this.ease() || !this.quiet(Harness.GAP) || !this.get_scale(true)) {
			return false;
		}
		if (!this.quiet(Harness.GAP) || !this.get_scale(false)) {
			return false;
		}
		if (this.policy == Policy.FRAME_PLAIN || !this.second_present) {
			if (!this.handler_done() || !this.quiet(Harness.DURATION)) {
				return false;
			}
			return this.end_turn();
		}
		this.new_frame_connected = true;
		if (!this.ack(Harness.NEW_FRAME) || !this.quiet(Harness.DURATION)) {
			return false;
		}
		if (!this.handler_done()) {
			return false;
		}
		if (!this.saw_stopped) {
			uint8 message;
			if (!Harness.read_byte(this.client_read, out message)
					|| message != Harness.STOPPED) {
				return false;
			}
			this.saw_stopped = true;
		}
		return this.end_turn();
	}

	private bool script_stopped()
	{
		this.grab_held = true;
		if (!this.ease() || !this.get_scale(true)) {
			return false;
		}
		if (!this.ack(Harness.SUBSCRIBE_STOPPED) || !this.quiet(Harness.GAP)) {
			return false;
		}
		if (!this.get_scale(false)) {
			return false;
		}
		return this.close_without_play();
	}

	private bool script_held()
	{
		this.grab_held = true;
		if (!this.ease() || !this.get_scale(true)) {
			return false;
		}
		if (!this.quiet(Harness.GAP) || !this.get_scale(false)) {
			return false;
		}
		if (this.second_present) {
			this.new_frame_connected = true;
		}
		if (!this.handler_done() || !this.quiet(Harness.DURATION)) {
			return false;
		}
		return this.end_turn();
	}

	private bool run_client()
	{
		switch (this.policy) {
		case Policy.SPLIT:
		case Policy.IN_PROCESS:
			return this.script_split();
		case Policy.PAUSE_ON_EASE:
		case Policy.PAUSE_PLAIN:
			return this.script_pause_ease();
		case Policy.PAUSE_ON_GET:
			return this.script_pause_get();
		case Policy.EASE_GAP:
			return this.script_ease_gap();
		case Policy.START_ON_FRAME:
		case Policy.FRAME_PLAIN:
			return this.script_frame();
		case Policy.START_ON_STOPPED:
			return this.script_stopped();
		case Policy.HOLD_CLICK:
		case Policy.INHIBIT_DRAG:
			return this.script_held();
		default:
			return false;
		}
	}

	public bool saved()
	{
		if (!this.grab_held || !this.first_present || !this.second_present) {
			return false;
		}
		if (!this.new_frame_connected || !this.saw_stopped) {
			return false;
		}
		if (this.scale_at_second != 1000 || this.scale_milli != 500) {
			return false;
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

		var server = new GLib.Thread<void*>("scale-gap-server", () => {
			this.server_ok = this.run_server();
			return null;
		});
		this.client_ok = this.run_client();
		server.join();

		Posix.close(client_to_server[0]);
		Posix.close(client_to_server[1]);
		Posix.close(server_to_client[0]);
		Posix.close(server_to_client[1]);
		return this.client_ok && this.server_ok;
	}
}

private static bool parse_policy(string name, out Policy policy)
{
	switch (name) {
	case "current":
		policy = Policy.SPLIT;
		return true;
	case "in-process":
		policy = Policy.IN_PROCESS;
		return true;
	case "pause-on-ease":
		policy = Policy.PAUSE_ON_EASE;
		return true;
	case "pause-plain":
		policy = Policy.PAUSE_PLAIN;
		return true;
	case "pause-on-get":
		policy = Policy.PAUSE_ON_GET;
		return true;
	case "ease-gap":
		policy = Policy.EASE_GAP;
		return true;
	case "start-on-frame":
		policy = Policy.START_ON_FRAME;
		return true;
	case "frame-plain":
		policy = Policy.FRAME_PLAIN;
		return true;
	case "start-on-stopped":
		policy = Policy.START_ON_STOPPED;
		return true;
	case "hold-until-click":
		policy = Policy.HOLD_CLICK;
		return true;
	case "inhibit-drag":
		policy = Policy.INHIBIT_DRAG;
		return true;
	default:
		policy = Policy.SPLIT;
		return false;
	}
}

int main(string[] args)
{
	Policy policy = Policy.SPLIT;
	if (args.length != 2 || !parse_policy(args[1], out policy)) {
		stderr.printf(
			"usage: %s current|in-process|pause-on-ease|pause-plain|pause-on-get|ease-gap|start-on-frame|frame-plain|start-on-stopped|hold-until-click|inhibit-drag\n",
			args[0]);
		return 2;
	}
	var harness = new Harness(policy);
	if (!harness.run()) {
		stderr.printf("FAIL %s: exchange did not complete\n", args[1]);
		return 2;
	}
	if (args[1] == "current") {
		if (harness.grab_held && harness.first_present
				&& !harness.second_present && harness.saw_stopped
				&& harness.stopped_while_open
				&& !harness.new_frame_connected) {
			stderr.printf(
				"FAIL current: scale-x gone before the handler returned\n");
			return 1;
		}
		stderr.printf(
			"PASS current: scale-x was still present when the handler read it\n");
		return 0;
	}
	if (args[1] == "in-process") {
		if (harness.grab_held && harness.first_present
				&& harness.second_present && harness.new_frame_connected
				&& harness.saw_stopped && !harness.stopped_while_open
				&& harness.scale_milli == 500
				&& harness.scale_at_second == 1000) {
			stderr.printf(
				"PASS in-process: scale-x stayed until the handler returned, then the scale finished\n");
			return 0;
		}
		stderr.printf(
			"FAIL in-process: clock moved while the handler was open\n");
		return 1;
	}
	if (args[1] == "pause-plain") {
		if (harness.grab_held && harness.first_present
				&& harness.second_present && !harness.new_frame_connected
				&& harness.saw_stopped && harness.scale_at_second == 1000
				&& harness.scale_milli == 500) {
			stderr.printf(
				"PASS pause-plain: ordinary ease survived the gap and then finished\n");
			return 0;
		}
		stderr.printf(
			"FAIL pause-plain: ordinary ease did not finish after the handler\n");
		return 1;
	}
	if (args[1] == "ease-gap") {
		if (!harness.first_present && harness.saw_stopped) {
			stderr.printf(
				"FAIL ease-gap: scale-x gone before the first get\n");
			return 1;
		}
		stderr.printf(
			"PASS ease-gap: scale-x survived a gap before the first get\n");
		return 0;
	}
	if (args[1] == "start-on-stopped") {
		if (harness.first_present && !harness.second_present
				&& harness.saw_stopped) {
			stderr.printf(
				"FAIL start-on-stopped: subscribing stopped let the gap finish the timeline\n");
			return 1;
		}
		stderr.printf(
			"PASS start-on-stopped: scale-x survived the subscribe\n");
		return 0;
	}
	if (args[1] == "hold-until-click") {
		if (harness.second_present && harness.new_frame_connected
				&& harness.scale_milli != 500) {
			stderr.printf(
				"FAIL hold-until-click: scale never finished, drag has no clicked\n");
			return 1;
		}
		stderr.printf(
			"PASS hold-until-click: scale finished without clicked\n");
		return 0;
	}
	if (args[1] == "inhibit-drag") {
		if (harness.second_present && harness.new_frame_connected
				&& harness.scale_milli != 500) {
			stderr.printf(
				"FAIL inhibit-drag: scale did not run while the grab was held\n");
			return 1;
		}
		stderr.printf(
			"PASS inhibit-drag: scale finished while the grab was held\n");
		return 0;
	}
	if (args[1] == "frame-plain") {
		if (harness.second_present && !harness.new_frame_connected
				&& harness.scale_milli != 500) {
			stderr.printf(
				"FAIL frame-plain: scale never started without new-frame\n");
			return 1;
		}
		stderr.printf(
			"PASS frame-plain: ordinary ease finished without new-frame\n");
		return 0;
	}
	if (harness.saved()) {
		stderr.printf(
			"PASS %s: scale-x stayed across the gap, then the scale finished\n",
			args[1]);
		return 0;
	}
	stderr.printf(
		"FAIL %s: scale-x did not stay across the gap\n",
		args[1]);
	return 1;
}
