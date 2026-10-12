namespace Gsr.Server
{
	/**
	 * Covers the stage during split-process shell startup.
	 *
	 * The notice stays the top actor until the owning connection
	 * releases the lock through global::Meta.Context.notify_ready.
	 * {@link begin} inhibits the current stage-view clocks from the
	 * startup RPC. {@link release} uninhibits them, then schedules
	 * an update. Do not inhibit from the frame that presented the
	 * notice: virtio keeps scanning that frame after the actor is gone.
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
		 * Notice covering the stage until {@link release}.
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
		private ulong connection_stopped_id;
		private global::Clutter.FrameClock[] clocks = {};

		[CCode (cname = "clutter_stage_view_get_frame_clock", cheader_filename = "clutter/clutter.h")]
		private static extern unowned global::Clutter.FrameClock view_frame_clock(global::Clutter.StageView view);

		/**
		 * Connection that currently owns the lock.
		 */
		public Gsr.Server.Rpc.Connection? connection { get; private set; }

		/**
		 * Create the startup notice for the display's stage.
		 *
		 * @param display compositor display whose stage shows the notice
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
		 * Raise the startup notice and keep it up until {@link release}.
		 *
		 * {@link begin} runs inside the startup RPC. Do not pump the main
		 * loop to wait for the notice frame. A nested iteration runs the
		 * frame clock on this stack and the next schedule_update segfaults.
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

			var stage = (global::Clutter.Stage) this.stage;
			if (stage.peek_stage_views().length() == 0) {
				this.release_internal();
				return false;
			}

			this.connection = connection;
			this.connection_stopped_id = connection.stopped.connect(() => {
				if (this.connection == connection) {
					this.release_internal();
				}
			});

			foreach (var view in stage.peek_stage_views()) {
				var clock = view_frame_clock(view);
				clock.inhibit();
				this.clocks += clock;
			}

			ulong paint_id = 0;
			paint_id = stage.after_update.connect(() => {
				stage.disconnect(paint_id);
				if (this.connection != connection) {
					return;
				}
				GLib.debug("startup notice painted");
			});
			stage.schedule_update();
			return true;
		}

		/**
		 * Remove the notice when called by the owning connection.
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

		private void release_internal()
		{
			if (this.splash_on_stage) {
				this.stage.remove_child(this.splash);
				this.splash_on_stage = false;
				GLib.debug("startup notice removed");
			}
			if (this.connection != null && this.connection_stopped_id != 0) {
				this.connection.disconnect(this.connection_stopped_id);
				this.connection_stopped_id = 0;
			}
			this.connection = null;
			foreach (var clock in this.clocks) {
				clock.uninhibit();
			}
			this.clocks = {};
			((global::Clutter.Stage) this.stage).schedule_update();
		}
	}
}
