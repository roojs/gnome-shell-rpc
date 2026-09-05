/**
 * Client {@link Meta.BackgroundContent} — stock attaches this as
 * {@link Clutter.Actor.content} on {@link BackgroundActor} create.
 * GJS uses {@code content.set({ background, vignette, … })}; property
 * setters relay state when {@link rpc_lid} is set.
 */
namespace Meta
{
	public class BackgroundContent : GLib.Object, Clutter.Content, OLLMrpc.Live.Handle
	{
		public uint64 rpc_lid { get; set construct; default = 0; }

		private Background? _background;
		private bool _vignette;
		private double _vignette_sharpness = 0.5;
		private double _brightness = 1.0;

		public Background background {
			get { return this._background; }
			set {
				this._background = value;
				if (this.rpc_lid != 0 && value != null) {
					GnomeShellRpc.call_value(
						"Meta-BackgroundContent.set_background",
						this,
						OLLMrpc.args("o", value)
					);
				}
			}
		}

		public bool vignette {
			get { return this._vignette; }
			set {
				this._vignette = value;
				this.push_vignette();
			}
		}

		public double vignette_sharpness {
			get { return this._vignette_sharpness; }
			set {
				this._vignette_sharpness = value;
				this.push_vignette();
			}
		}

		public double brightness {
			get { return this._brightness; }
			set {
				this._brightness = value;
				this.push_vignette();
			}
		}

		public BackgroundContent()
		{
			Object();
		}

		private void push_vignette()
		{
			if (this.rpc_lid == 0) {
				return;
			}
			GnomeShellRpc.call_value(
				"Meta-BackgroundContent.set_vignette",
				this,
				OLLMrpc.args(
					"bdd",
					this._vignette,
					this._brightness,
					this._vignette_sharpness
				)
			);
		}

		public bool get_preferred_size(out float width, out float height)
		{
			// GJS never calls this — Clutter C layout only. Stock also reports
			// no size until a Cogl texture exists; we do not RPC (compositor
			// leased content answers layout on the server stage).
			width = 0;
			height = 0;
			return false;
		}

		public void paint_content(
			Clutter.Actor actor,
			Clutter.PaintNode node,
			Clutter.PaintContext paint_context
		) {
			// GJS never calls this — Clutter C paint vfunc only. Do not RPC
			// frames; the leased BackgroundActor on mutter-rpc already has
			// real MetaBackgroundContent and paints there. This object is the
			// GJS-facing facade (same split as PaintedContent / no local Cogl).
		}

		public void attached(Clutter.Actor actor)
		{
			// GJS never calls this — Clutter C lifecycle only. No RPC: server
			// Helper-BackgroundActor.create already attaches real content to
			// the leased actor. Client attach only exposes actor.content for
			// GJS; state crosses via set_background / set_vignette.
		}

		public void detached(Clutter.Actor actor)
		{
			// GJS never calls this — same as attached; local Clutter only.
		}

		public void invalidate()
		{
			// GJS never calls this — Clutter C dirty hook only. No RPC: server
			// content is invalidated when set_background / set_vignette run on
			// the leased object. No client-side render cache here.
		}

		public void invalidate_size()
		{
			// GJS never calls this — same as invalidate; see get_preferred_size.
		}
	}
}
