/**
 * Client peer for a compositor-side {@link GLib.Subprocess} created by
 * {@link Meta.WaylandClient.spawnv}. Lease id matches the WaylandClient.
 *
 * Stock GIR returns {@link GLib.Subprocess} (foreign — not on the wire).
 * This peer is client-only marshalling for wait / stdout / signals (DING).
 * Not a stock Meta type.
 */
namespace Meta
{
	public class RpcSubprocess : GLib.Object, OLLMrpc.Live.Handle
	{
		public uint64 rpc_lid { get; set construct; default = 0; }
		private GLib.InputStream? stdout_pipe = null;

		public RpcSubprocess(uint64 lid, int stdout_fd = -1)
		{
			Object(rpc_lid: lid);
			if (stdout_fd >= 0) {
				this.stdout_pipe = new GLib.UnixInputStream(stdout_fd, true);
			}
		}

		public GLib.InputStream? get_stdout_pipe()
		{
			return this.stdout_pipe;
		}

		public async bool wait_async(
			GLib.Cancellable? cancellable = null
		) throws GLib.Error {
			var response = GnomeShellRpc.call_value(
				"Helper-WaylandClient.wait", this
			);
			return response.retval.get_boolean();
		}

		public bool get_if_exited()
		{
			try {
				var response = GnomeShellRpc.call_value(
					"Helper-WaylandClient.get_if_exited", this
				);
				return response.retval.get_boolean();
			} catch (GLib.Error e) {
				return false;
			}
		}

		public int get_exit_status()
		{
			try {
				var response = GnomeShellRpc.call_value(
					"Helper-WaylandClient.get_exit_status", this
				);
				return response.retval.get_int();
			} catch (GLib.Error e) {
				return -1;
			}
		}

		public void send_signal(int signal_num)
		{
			try {
				GnomeShellRpc.call_value(
					"Helper-WaylandClient.send_signal", this,
					OLLMrpc.args("i", signal_num)
				);
			} catch (GLib.Error e) {
			}
		}

		public void force_exit()
		{
			try {
				GnomeShellRpc.call_value(
					"Helper-WaylandClient.force_exit", this
				);
			} catch (GLib.Error e) {
			}
		}
	}
}
