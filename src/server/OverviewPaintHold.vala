namespace Gsr.Server
{
	[CCode (cname = "clutter_stage_view_get_frame_clock", cheader_filename = "clutter/clutter.h")]
	extern unowned global::Clutter.FrameClock clutter_stage_view_get_frame_clock(global::Clutter.StageView view);

	/**
	 * Stops stage updates from the first {@code overviewGroup} show
	 * until the controls actor sets opacity to 0.
	 *
	 * One shot. A later overview show does not take the hold.
	 * A child opacity is not the release. Do not call this from a
	 * frame: virtio keeps scanning a frame that was inhibited.
	 *
	 * == Example ==
	 *
	 * {{{
	 * var hold = new OverviewPaintHold();
	 * hold.watch(actor, connection);
	 * }}}
	 */
	public class OverviewPaintHold : GLib.Object
	{
		private bool spent;
		private bool held;
		private ulong opacity_id;
		private ulong stopped_id;
		private ulong added_id;
		private global::Clutter.Actor? controls;
		private global::Clutter.FrameClock[] clocks = {};
		private Gsr.Server.Rpc.Connection? connection;

		/**
		 * Watch one newly minted actor for the overview-group name.
		 *
		 * @param actor widget just minted
		 * @param connection shell connection that minted it
		 */
		public void watch(
			global::Clutter.Actor actor,
			Gsr.Server.Rpc.Connection connection) {
			actor.notify.connect((pspec) => {
				if (this.spent) {
					return;
				}
				if (pspec.name != "visible" && pspec.name != "name") {
					return;
				}
				if (actor.name != "overviewGroup" || !actor.visible) {
					return;
				}
				this.connection = connection;
				this.on_shown(actor);
			});
		}

		private void on_shown(global::Clutter.Actor group)
		{
			if (this.spent || this.held) {
				return;
			}
			var found = this.find_controls(group);
			if (found != null) {
				this.hold(group, found);
				return;
			}
			if (this.added_id != 0) {
				return;
			}
			this.added_id = group.child_added.connect((child) => {
				if (this.spent || this.held) {
					return;
				}
				var late = this.find_controls(group);
				if (late != null) {
					this.hold(group, late);
				}
			});
		}

		private global::Clutter.Actor? find_controls(global::Clutter.Actor actor)
		{
			var widget = actor as global::St.Widget;
			if (widget != null) {
				var style = widget.get_style_class_name();
				if (style == "controls-manager") {
					return actor;
				}
			}
			for (var i = 0; i < actor.get_n_children(); i++) {
				var child = actor.get_child_at_index(i);
				if (child == null) {
					continue;
				}
				var found = this.find_controls(child);
				if (found != null) {
					return found;
				}
			}
			return null;
		}

		private void hold(
			global::Clutter.Actor group,
			global::Clutter.Actor controls) {
			var stage = group.get_stage() as global::Clutter.Stage;
			if (stage == null || stage.peek_stage_views().length() == 0) {
				return;
			}
			foreach (var view in stage.peek_stage_views()) {
				var clock = clutter_stage_view_get_frame_clock(view);
				clock.inhibit();
				this.clocks += clock;
			}
			this.controls = controls;
			this.held = true;
			this.opacity_id = controls.notify["opacity"].connect(() => {
				if (controls.opacity != 0) {
					return;
				}
				this.release(stage);
			});
			if (this.connection != null) {
				this.stopped_id = this.connection.stopped.connect(() => {
					this.release(stage);
				});
			}
		}

		private void release(global::Clutter.Stage stage)
		{
			if (!this.held) {
				return;
			}
			if (this.controls != null && this.opacity_id != 0) {
				this.controls.disconnect(this.opacity_id);
				this.opacity_id = 0;
			}
			if (this.connection != null && this.stopped_id != 0) {
				this.connection.disconnect(this.stopped_id);
				this.stopped_id = 0;
			}
			foreach (var clock in this.clocks) {
				clock.uninhibit();
			}
			this.clocks = {};
			this.controls = null;
			this.connection = null;
			this.held = false;
			this.spent = true;
			stage.schedule_update();
		}
	}
}
