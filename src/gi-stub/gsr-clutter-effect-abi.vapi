/* C GTypes from c-clutter-effect-abi.c; method bodies in ClutterEffectRelay.vala. */
[CCode (cprefix = "Clutter", lower_case_cprefix = "clutter_", cheader_filename = "gsr-clutter-effect-abi.h")]
namespace Clutter {
	[CCode (type_id = "CLUTTER_TYPE_ACTOR_META")]
	public class ActorMeta : GLib.InitiallyUnowned {
		[CCode (has_construct_function = false)]
		protected ActorMeta ();

		public Actor get_actor ();
		public bool get_enabled ();
		public unowned string get_name ();
		public void set_enabled (bool is_enabled);
		public void set_name (string name);
	}

	[CCode (type_id = "CLUTTER_TYPE_EFFECT")]
	public class Effect : ActorMeta {
		[CCode (has_construct_function = false)]
		protected Effect ();

		public void queue_repaint ();
	}

	[CCode (type_id = "CLUTTER_TYPE_OFFSCREEN_EFFECT")]
	public class OffscreenEffect : Effect {
		[CCode (has_construct_function = false)]
		protected OffscreenEffect ();

		public Cogl.Texture create_texture (Cogl.Context context, float width, float height);
		public Cogl.Pipeline get_pipeline ();
		public bool get_target_size (out float width, out float height);
		public Cogl.Texture get_texture ();
		public void paint_target (PaintNode node, PaintContext paint_context);
	}
}
