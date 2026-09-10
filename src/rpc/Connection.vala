/**
 * Server connection that can read during sync {@link OLLMrpc.Live.Hook.emit}.
 *
 * Default OPC {@code emit_wait_poll} uses {@code MainContext.iteration}, which
 * cannot re-enter the connection IO watch mid-{@code on_input_ready}. Override
 * with {@link GLib.poll} + the same parse/dispatch loop as the watch.
 */
namespace GnomeShellRpc.Rpc
{
	public class Connection : OLLMrpc.Transport.Connection
	{
		public Connection(GLib.SocketConnection? stream = null)
		{
			GLib.Object(stream: stream);
		}

		public override void emit_wait_poll()
		{
			if (!this.channel_open || this.channel == null || this.bin == null) {
				base.emit_wait_poll();
				return;
			}

			if ((this.channel.get_buffer_condition() & GLib.IOCondition.IN) != 0) {
				this.drain_readable();
				return;
			}

			var poll_source = GLib.PollFD();
			poll_source.fd = this.channel.unix_get_fd();
			poll_source.events =
				GLib.IOCondition.IN | GLib.IOCondition.ERR | GLib.IOCondition.HUP;
			var poll_fds = new GLib.PollFD[] { poll_source };
			if (GLib.poll(poll_fds, -1) <= 0) {
				return;
			}
			if ((poll_fds[0].revents & GLib.IOCondition.ERR) != 0
					|| (poll_fds[0].revents & GLib.IOCondition.HUP) != 0) {
				this.stop();
				return;
			}
			if ((poll_fds[0].revents & GLib.IOCondition.IN) == 0) {
				return;
			}
			this.drain_readable();
		}

		/**
		 * Same body as OPC {@code on_input_ready} inner loop — readable
		 * without going through the IO watch (safe mid-dispatch).
		 */
		private void drain_readable()
		{
			do {
				if (!this.channel_open || this.bin == null) {
					break;
				}
				OLLMrpc.Request? request = null;
				try {
					request = this.bin.parse() as OLLMrpc.Request;
				} catch (GLib.Error e) {
					GLib.error("%s", e.message);
				}
				if (request == null) {
					GLib.warning("connection read: expected Request");
					break;
				}
				GLib.debug(
					"recv id=%d method=%s conn=%p",
					request.id,
					request.method,
					this
				);
				request.connection = this;
				if (!request.dispatch()) {
					this.reply_error(
						request,
						(int) OLLMrpc.RpcErrorCode.METHOD_NOT_FOUND
					);
				}
			} while (
				this.channel != null
				&& (this.channel.get_buffer_condition() & GLib.IOCondition.IN) != 0
			);
		}
	}
}
