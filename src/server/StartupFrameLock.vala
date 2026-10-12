namespace Gsr.Server
{
	/**
	 * Inhibits compositor frames during split-process shell startup.
	 *
	 * A notice covers the stage and is presented before the clocks
	 * stop, so the frozen frame is that notice. The shell client takes
	 * the lock before evaluating stock init.js. The owning connection
	 * releases it through global::Meta.Context.notify_ready, which
	 * removes the notice first. Frame clocks retain pending updates
	 * while inhibited.
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
		/**
		 * Notice covering the stage while startup frames are inhibited.
		 * Removed before the clocks resume.
		 */
		private global::Clutter.Actor splash {
			get; set; default = new global::Clutter.Actor() {
				background_color = global::Cogl.Color.from_4f(0.16f, 0.16f, 0.18f, 1.0f),
			};
		}
		/**
		 * True while {@link splash} is a child of the stage.
		 */
		private bool splash_on_stage = false;
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
			this.splash.add_constraint(new global::Clutter.BindConstraint(
				this.stage, global::Clutter.BindCoordinate.SIZE, 0));
			var label = new global::Clutter.Text() {
				text = "Starting GNOME Shell",
				font_name = "Sans Bold 17",
				color = global::Cogl.Color.from_4f(1.0f, 1.0f, 1.0f, 1.0f),
				selectable = false,
			};
			label.add_constraint(new global::Clutter.AlignConstraint(
				this.splash, global::Clutter.AlignAxis.BOTH, 0.5f));
			this.splash.add_child(label);
			this.stage.insert_child_above(this.splash, null);
			this.splash_on_stage = true;
		}

		/**
		 * Present the startup notice, then inhibit every current
		 * stage-view frame clock. The notice stays on the frozen frame
		 * until {@link release}.
		 *
		 * @param connection startup connection that owns the lock
		 * @return true when the lock was taken
		 */
		public bool begin(Gsr.Server.Rpc.Connection connection)
		{
			if (this.connection != null) {
				return false;
			}

			if (!this.splash_on_stage) {
				this.stage.insert_child_above(this.splash, null);
				this.splash_on_stage = true;
			}
			this.stage.set_child_above_sibling(this.splash, null);
			this.splash.queue_redraw();

			/* Inhibit keeps the last presented frame. Present the notice
			 * first, or that frame is still empty. */
			var stage = (global::Clutter.Stage) this.stage;
			var views_left = (int) stage.peek_stage_views().length();
			if (views_left > 0) {
				var paint_id = stage.after_update.connect(() => {
					views_left--;
				});
				stage.schedule_update();
				var deadline = GLib.get_monotonic_time() + 500000;
				while (views_left > 0 && GLib.get_monotonic_time() < deadline) {
					if (!GLib.MainContext.default().iteration(true)) {
						break;
					}
				}
				stage.disconnect(paint_id);
				if (views_left > 0) {
					GLib.warning("startup notice was not painted");
				}
				if (views_left <= 0) {
					GLib.debug("startup notice painted");
				}
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
			if (this.splash_on_stage) {
				this.stage.remove_child(this.splash);
				this.splash_on_stage = false;
				GLib.debug("startup notice removed");
			}
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
