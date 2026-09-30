/**
 * Owned {@code Shell.WindowPreviewLayout} — stock
 * {@code shell-window-preview-layout.c}.
 *
 * Client-local {@link Clutter.LayoutManager} ({@code rpc_lid} stays 0):
 * measure/allocate run here; each tracked window is a
 * {@link WindowEntry} (Vala constructor, leased {@link Clutter.Clone}).
 */
namespace Shell
{
	public class WindowPreviewLayout : Clutter.LayoutManager
	{
		/**
		 * One overview peek: leased clone of the window actor, plus the
		 * signal wiring that keeps layout in sync.
		 */
		private class WindowEntry
		{
			public Meta.Window window { get; private set; }
			public Clutter.Actor actor_copy { get; private set; }

			private Clutter.Actor window_actor;
			private ulong size_changed_id;
			private ulong position_changed_id;
			private ulong window_actor_destroy_id;
			private ulong destroy_id;
			private weak WindowPreviewLayout layout;

			public WindowEntry(WindowPreviewLayout layout, Meta.Window window)
			{
				this.layout = layout;
				this.window = window;
				this.window_actor = (Clutter.Actor) window.get_compositor_private();
				this.actor_copy = new Clutter.Clone(this.window_actor);
				this.size_changed_id = window.signal_size_changed.connect(() => {
					layout.windows_changed();
				});
				this.position_changed_id = window.signal_position_changed.connect(() => {
					layout.windows_changed();
				});
				this.window_actor_destroy_id = this.window_actor.signal_destroy.connect(() => {
					this.actor_copy.signal_destroy();
				});
				this.destroy_id = this.actor_copy.signal_destroy.connect(() => {
					layout.remove_window(window);
				});
			}

			public void detach()
			{
				this.window.disconnect(this.size_changed_id);
				this.window.disconnect(this.position_changed_id);
				this.window_actor.disconnect(this.window_actor_destroy_id);
				this.actor_copy.disconnect(this.destroy_id);
			}
		}

		private Clutter.Actor? container;
		private Gee.HashMap<Meta.Window, WindowEntry> entries = new Gee.HashMap<Meta.Window, WindowEntry>();
		private Clutter.ActorBox priv_bounding_box;

		public Clutter.ActorBox bounding_box {
			get {
				return this.priv_bounding_box;
			}
		}

		public override void set_container_vfunc(Clutter.Actor? container)
		{
			this.container = container;
			base.set_container_vfunc(container);
		}

		public override void get_preferred_width_vfunc(Clutter.Actor container, float for_height,
				out float min_width_p, out float nat_width_p) {
			min_width_p = 0f;
			nat_width_p = this.priv_bounding_box.get_width();
		}

		public override void get_preferred_height_vfunc(Clutter.Actor container, float for_width,
				out float min_height_p, out float nat_height_p) {
			min_height_p = 0f;
			nat_height_p = this.priv_bounding_box.get_height();
		}

		public override void allocate_vfunc(Clutter.Actor container, Clutter.ActorBox box)
		{
			var bounding_box_width = this.priv_bounding_box.get_width();
			var bounding_box_height = this.priv_bounding_box.get_height();
			var scale_x = bounding_box_width == 0f ? 1f : box.get_width() / bounding_box_width;
			var scale_y = bounding_box_height == 0f ? 1f : box.get_height() / bounding_box_height;

			for (var child = container.first_child; child != null; child = child.get_next_sibling()) {
				if (!child.is_visible()) {
					continue;
				}

				WindowEntry? entry = null;
				foreach (var candidate in this.entries.values) {
					if (candidate.actor_copy != child) {
						continue;
					}
					entry = candidate;
					break;
				}
				if (entry == null) {
					float x, y;
					child.get_fixed_position(out x, out y);
					child.allocate_preferred_size(x, y);
					continue;
				}

				Mtk.Rectangle buffer_rect;
				entry.window.get_buffer_rect(out buffer_rect);
				float child_nat_width, child_nat_height, unused_min_w, unused_min_h;
				child.get_preferred_size(out unused_min_w, out unused_min_h,
					out child_nat_width, out child_nat_height);

				var child_box = Clutter.ActorBox();
				child_box.set_origin((float) buffer_rect.x - this.priv_bounding_box.x1,
					(float) buffer_rect.y - this.priv_bounding_box.y1);
				child_box.set_size(child_nat_width, child_nat_height);
				child_box.x1 *= scale_x;
				child_box.x2 *= scale_x;
				child_box.y1 *= scale_y;
				child_box.y2 *= scale_y;
				child.allocate(child_box);
			}
		}

		public Clutter.Actor? add_window(Meta.Window window)
		{
			if (this.entries.has_key(window)) {
				return null;
			}

			var entry = new WindowEntry(this, window);
			this.entries.set(window, entry);
			this.container.add_child(entry.actor_copy);
			this.windows_changed();
			return entry.actor_copy;
		}

		public void remove_window(Meta.Window window)
		{
			if (!this.entries.has_key(window)) {
				return;
			}

			var entry = this.entries.get(window);
			entry.detach();
			this.entries.unset(window);
			this.container.remove_child(entry.actor_copy);
			this.windows_changed();
		}

		public GLib.List<weak Meta.Window> get_windows()
		{
			var windows = new GLib.List<weak Meta.Window>();
			foreach (var window in this.entries.keys) {
				windows.prepend(window);
			}
			return (owned) windows;
		}

		public override void dispose()
		{
			foreach (var window in this.entries.keys.to_array()) {
				var entry = this.entries.get(window);
				entry.detach();
				this.container.remove_child(entry.actor_copy);
			}
			this.entries.clear();
			base.dispose();
		}

		internal void windows_changed()
		{
			var old_bounding_box = this.priv_bounding_box;
			var first_rect = true;
			Mtk.Rectangle bounding_rect = { 0, 0, 0, 0 };

			foreach (var entry in this.entries.values) {
				Mtk.Rectangle frame_rect;
				entry.window.get_frame_rect(out frame_rect);
				if (first_rect) {
					bounding_rect = frame_rect;
					first_rect = false;
					continue;
				}
				bounding_rect = bounding_rect.union(frame_rect);
			}

			this.priv_bounding_box.set_origin((float) bounding_rect.x, 
				(float) bounding_rect.y);
			this.priv_bounding_box.set_size((float) bounding_rect.width, 
				(float) bounding_rect.height);

			if (!this.priv_bounding_box.equal(old_bounding_box)) {
				this.notify_property("bounding-box");
			}
			this.layout_changed_invoke();
		}
	}
}
