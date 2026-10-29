/**
 * Frame between show and the opacity write in the same client turn.
 *
 * overviewControls.js sets controls opacity to 0 in the same turn as
 * showOverview(), before the first await. One process does not paint until
 * that turn returns, so the window picker is never a frame. current is the
 * RPC split: the server paints in the quiet gap after show returns and
 * before the opacity write. in-process is the single-process clock.
 * hold-turn keeps a frame until the turn yields. It needs a yield signal,
 * which is not a product path. poll blocks the read loop until a quiet
 * expires. flow-idle stops the clock while the exchange is still going
 * and starts it when that flow goes idle, and an input event during the
 * hold is still handled. None of the modes link product source.
 */

private enum Policy
{
	SPLIT,
	IN_PROCESS,
	HOLD_TURN,
	POLL,
	POLL_SHORT,
	FLOW_IDLE,
}

private class Harness
{
	private const uint8 SHOW = (uint8) 'S';
	private const uint8 OPACITY = (uint8) 'O';
	private const uint8 QUIET = (uint8) 'Q';
	private const uint8 YIELD = (uint8) 'Y';
	private const uint8 END = (uint8) 'X';
	private const uint8 ACK = (uint8) 'K';
	private const uint8 INPUT = (uint8) 'I';
	private const uint8 IN_TURN = 2;
	private const uint8 AFTER_TURN = 20;
	private const int POLL_LIMIT = 8;

	private Policy policy;
	private int client_read;
	private int client_write;
	private int server_read;
	private int server_write;
	private bool handler_open;
	private bool shown;
	private int opacity;
	private bool deferred;
	private bool server_ok;
	private bool client_ok;

	public int bad_frames;
	public int good_frames;
	public int input_ran;

	public Harness(Policy policy)
	{
		this.policy = policy;
		this.handler_open = true;
		this.opacity = 255;
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

	private bool hold_while_open()
	{
		return this.policy == Policy.IN_PROCESS
			|| this.policy == Policy.HOLD_TURN;
	}

	private void present()
	{
		if (!this.shown) {
			return;
		}
		if (this.opacity >= 200) {
			this.bad_frames++;
			return;
		}
		if (this.opacity == 0) {
			this.good_frames++;
		}
	}

	private int poll_limit()
	{
		if (this.policy == Policy.POLL) {
			return Harness.POLL_LIMIT;
		}
		return 1;
	}

	private bool flow_idle_policy()
	{
		return this.policy == Policy.FLOW_IDLE;
	}

	private void gap(int duration)
	{
		if (this.policy == Policy.POLL || this.policy == Policy.POLL_SHORT) {
			if (duration < this.poll_limit()) {
				return;
			}
			this.present();
			return;
		}
		if (this.flow_idle_policy()) {
			if (duration < Harness.AFTER_TURN) {
				return;
			}
			this.present();
			return;
		}
		if (this.hold_while_open() && this.handler_open) {
			this.deferred = true;
			return;
		}
		this.present();
	}

	private bool run_server()
	{
		while (true) {
			uint8 message;
			if (!Harness.read_byte(this.server_read, out message)) {
				return false;
			}
			if (message == Harness.SHOW) {
				this.shown = true;
				if (!Harness.write_byte(this.server_write, Harness.ACK)) {
					return false;
				}
				continue;
			}
			if (message == Harness.OPACITY) {
				this.opacity = 0;
				if (!Harness.write_byte(this.server_write, Harness.ACK)) {
					return false;
				}
				continue;
			}
			if (message == Harness.QUIET) {
				uint8 duration;
				if (!Harness.read_byte(this.server_read, out duration)) {
					return false;
				}
				this.gap(duration);
				continue;
			}
			if (message == Harness.INPUT) {
				this.input_ran++;
				continue;
			}
			if (message == Harness.YIELD) {
				this.handler_open = false;
				if (this.deferred) {
					this.deferred = false;
					this.present();
				}
				continue;
			}
			if (message == Harness.END) {
				return true;
			}
			return false;
		}
	}

	private bool run_client()
	{
		if (!Harness.write_byte(this.client_write, Harness.SHOW)) {
			return false;
		}
		uint8 ack;
		if (!Harness.read_byte(this.client_read, out ack) || ack != Harness.ACK) {
			return false;
		}
		if (!Harness.write_byte(this.client_write, Harness.QUIET)
				|| !Harness.write_byte(this.client_write, Harness.IN_TURN)) {
			return false;
		}
		if (!Harness.write_byte(this.client_write, Harness.INPUT)) {
			return false;
		}
		if (!Harness.write_byte(this.client_write, Harness.OPACITY)) {
			return false;
		}
		if (!Harness.read_byte(this.client_read, out ack) || ack != Harness.ACK) {
			return false;
		}
		if (!Harness.write_byte(this.client_write, Harness.QUIET)
				|| !Harness.write_byte(this.client_write, Harness.IN_TURN)) {
			return false;
		}
		if (!Harness.write_byte(this.client_write, Harness.YIELD)) {
			return false;
		}
		if (!Harness.write_byte(this.client_write, Harness.QUIET)
				|| !Harness.write_byte(this.client_write, Harness.AFTER_TURN)) {
			return false;
		}
		return Harness.write_byte(this.client_write, Harness.END);
	}

	public bool run()
	{
		int[] client_to_server = new int[2];
		int[] server_to_client = new int[2];
		if (Posix.pipe(client_to_server) != 0
				|| Posix.pipe(server_to_client) != 0) {
			return false;
		}
		this.client_read = server_to_client[0];
		this.client_write = client_to_server[1];
		this.server_read = client_to_server[0];
		this.server_write = server_to_client[1];

		var server = new GLib.Thread<void*>("startup-paint-gap-server", () => {
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
	case "hold-turn":
		policy = Policy.HOLD_TURN;
		return true;
	case "poll":
		policy = Policy.POLL;
		return true;
	case "poll-short":
		policy = Policy.POLL_SHORT;
		return true;
	case "flow-idle":
		policy = Policy.FLOW_IDLE;
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
			"usage: %s current|in-process|hold-turn|poll|poll-short|flow-idle\n",
			args[0]);
		return 2;
	}
	var harness = new Harness(policy);
	if (!harness.run()) {
		stderr.printf("FAIL %s: exchange did not complete\n", args[1]);
		return 2;
	}
	if (args[1] == "current" || args[1] == "poll-short") {
		if (harness.bad_frames > 0 && harness.good_frames > 0) {
			stderr.printf(
				"FAIL %s: frame at opacity 255 while the turn was still open\n",
				args[1]);
			return 1;
		}
		if (args[1] == "current") {
			stderr.printf(
				"PASS current: no frame at opacity 255 before the turn yielded\n");
			return 0;
		}
	}
	if (args[1] == "flow-idle") {
		if (harness.bad_frames == 0 && harness.good_frames > 0
				&& harness.input_ran > 0) {
			stderr.printf(
				"PASS flow-idle: clock started when the flow went idle, input ran while it was stopped\n");
			return 0;
		}
		stderr.printf(
			"FAIL flow-idle: bad=%d good=%d input=%d\n",
			harness.bad_frames, harness.good_frames, harness.input_ran);
		return 1;
	}
	if (harness.bad_frames == 0 && harness.good_frames > 0) {
		stderr.printf(
			"PASS %s: first frame is opacity 0, after the turn yielded\n",
			args[1]);
		return 0;
	}
	stderr.printf(
		"FAIL %s: bad=%d good=%d\n",
		args[1], harness.bad_frames, harness.good_frames);
	return 1;
}
