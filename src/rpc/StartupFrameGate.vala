namespace GnomeShellRpc.Rpc
{
	/**
	 * Inhibits compositor frames during split-process shell startup.
	 *
	 * The shell client opens the gate before evaluating stock init.js.
	 * The owning connection closes it through Meta.Context.notify_ready.
	 * Frame clocks retain pending updates while inhibited.
	 *
	 * == Example ==
	 *
	 * {{{
	 * var gate = new StartupFrameGate(display);
	 * gate.begin(connection);
	 * gate.release(connection);
	 * }}}
	 */
	public class StartupFrameGate : GLib.Object
	{
		private Clutter.Actor stage;
		private Gee.HashSet<Clutter.FrameClock> clocks = new Gee.HashSet<Clutter.FrameClock>();
		private ulong stage_views_changed_id;
		private ulong connection_stopped_id;

		[CCode (cname = "clutter_stage_view_get_frame_clock",
			cheader_filename = "clutter/clutter.h")]
		private static extern Clutter.FrameClock frame_clock(Clutter.StageView view);

		/**
		 * Connection that currently owns the gate.
		 */
		public Connection? connection { get; private set; }

		/**
		 * Create a frame gate for the display's stage.
		 *
		 * @param display compositor display whose stage clocks are gated
		 */
		public StartupFrameGate(Meta.Display display)
		{
			this.stage = display.get_context().get_backend().get_stage();
		}

		/**
		 * Inhibit every current stage-view frame clock.
		 *
		 * @param connection startup connection that owns the gate
		 * @return true when the gate was opened
		 */
		public bool begin(Connection connection)
		{
			if (this.connection != null) {
				return false;
			}

			this.connection = connection;
			this.connection_stopped_id = connection.stopped.connect(() => {
				if (this.connection == connection) {
					this.release_internal();
				}
			});
			this.stage_views_changed_id = this.stage.stage_views_changed.connect(
				this.reconcile_views);
			this.reconcile_views();

			if (this.clocks.size == 0) {
				this.release_internal();
				return false;
			}
			return true;
		}

		/**
		 * Uninhibit clocks when called by the owning connection.
		 *
		 * @param connection connection requesting release
		 * @return true when inactive or released by the owner
		 */
		public bool release(Connection connection)
		{
			if (this.connection == null) {
				return true;
			}
			if (this.connection != connection) {
				return false;
			}
			this.release_internal();
			return true;
		}

		private void reconcile_views()
		{
			var current = new Gee.HashSet<Clutter.FrameClock>();
			foreach (var view in this.stage.peek_stage_views()) {
				var clock = StartupFrameGate.frame_clock(view);
				current.add(clock);
				if (!this.clocks.contains(clock)) {
					clock.inhibit();
				}
			}

			foreach (var clock in this.clocks) {
				if (!current.contains(clock)) {
					clock.uninhibit();
				}
			}
			this.clocks = current;
		}

		private void release_internal()
		{
			if (this.stage_views_changed_id != 0) {
				this.stage.disconnect(this.stage_views_changed_id);
				this.stage_views_changed_id = 0;
			}
			if (this.connection != null && this.connection_stopped_id != 0) {
				this.connection.disconnect(this.connection_stopped_id);
				this.connection_stopped_id = 0;
			}
			foreach (var clock in this.clocks) {
				clock.uninhibit();
			}
			this.clocks.clear();
			this.connection = null;
		}
	}
}
