namespace Gsr.Server
{
	/**
	 * Inhibits compositor frames during split-process shell startup.
	 *
	 * The shell client takes the lock before evaluating stock init.js.
	 * The owning connection releases it through global::Meta.Context.notify_ready.
	 * Frame clocks retain pending updates while inhibited.
	 *
	 * == Example ==
	 *
	 * {{{
	 * var lock = new StartupFrameLock(display);
	 * lock.begin(connection);
	 * lock.release(connection);
	 * }}}
	 */
	public class StartupFrameLock : GLib.Object
	{
		private global::Clutter.Actor stage;
		private Gee.HashSet<global::Clutter.FrameClock> clocks = new Gee.HashSet<global::Clutter.FrameClock>();
		private ulong stage_views_changed_id;
		private ulong connection_stopped_id;

		[CCode (cname = "clutter_stage_view_get_frame_clock",
			cheader_filename = "clutter/clutter.h")]
		private static extern global::Clutter.FrameClock frame_clock(global::Clutter.StageView view);

		/**
		 * Connection that currently owns the lock.
		 */
		public Gsr.Server.Rpc.Connection? connection { get; private set; }

		/**
		 * Create a frame lock for the display's stage.
		 *
		 * @param display compositor display whose stage clocks are locked
		 */
		public StartupFrameLock(global::Meta.Display display)
		{
			this.stage = display.get_context().get_backend().get_stage();
		}

		/**
		 * Inhibit every current stage-view frame clock.
		 *
		 * @param connection startup connection that owns the lock
		 * @return true when the lock was taken
		 */
		public bool begin(Gsr.Server.Rpc.Connection connection)
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
		public bool release(Gsr.Server.Rpc.Connection connection)
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
			var current = new Gee.HashSet<global::Clutter.FrameClock>();
			foreach (var view in this.stage.peek_stage_views()) {
				var clock = StartupFrameLock.frame_clock(view);
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
