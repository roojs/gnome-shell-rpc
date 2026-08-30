/**
 * RPC bodies for {@link ActorMeta} / {@link Effect} / {@link OffscreenEffect}.
 *
 * GTypes come from {@code c-clutter-effect-abi.c}; these {@code [CCode]}
 * symbols match the typelib / vapi instance methods.
 */
namespace Clutter
{
	[CCode (cname = "clutter_actor_meta_get_actor")]
	public Actor actor_meta_get_actor(ActorMeta self)
	{
		var response = GnomeShellRpc.GiStub.Runtime.call_values(
			"Clutter-ActorMeta.get_actor", self);
		return (Actor) response.retval.get_object();
	}

	[CCode (cname = "clutter_actor_meta_get_enabled")]
	public bool actor_meta_get_enabled(ActorMeta self)
	{
		var response = GnomeShellRpc.GiStub.Runtime.call_values(
			"Clutter-ActorMeta.get_enabled", self);
		return response.retval.get_boolean();
	}

	[CCode (cname = "clutter_actor_meta_get_name")]
	public unowned string actor_meta_get_name(ActorMeta self)
	{
		var response = GnomeShellRpc.GiStub.Runtime.call_values(
			"Clutter-ActorMeta.get_name", self);
		return response.retval.get_string();
	}

	[CCode (cname = "clutter_actor_meta_set_enabled")]
	public void actor_meta_set_enabled(ActorMeta self, bool is_enabled)
	{
		GnomeShellRpc.GiStub.Runtime.call_values(
			"Clutter-ActorMeta.set_enabled", self,
			OLLMrpc.args("b", is_enabled));
	}

	[CCode (cname = "clutter_actor_meta_set_name")]
	public void actor_meta_set_name(ActorMeta self, string name)
	{
		GnomeShellRpc.GiStub.Runtime.call_values(
			"Clutter-ActorMeta.set_name", self,
			OLLMrpc.args("s", name));
	}

	[CCode (cname = "clutter_effect_queue_repaint")]
	public void effect_queue_repaint(Effect self)
	{
		GnomeShellRpc.GiStub.Runtime.call_values(
			"Clutter-Effect.queue_repaint", self);
	}

	[CCode (cname = "clutter_offscreen_effect_create_texture")]
	public Cogl.Texture offscreen_effect_create_texture(
		OffscreenEffect effect,
		Cogl.Context context,
		float width,
		float height
	) {
		GLib.error("gi-stub: Clutter-OffscreenEffect.create_texture not wired");
	}

	[CCode (cname = "clutter_offscreen_effect_get_pipeline")]
	public Cogl.Pipeline offscreen_effect_get_pipeline(OffscreenEffect effect)
	{
		var response = GnomeShellRpc.GiStub.Runtime.call_values(
			"Clutter-OffscreenEffect.get_pipeline", effect);
		return (Cogl.Pipeline) response.retval.get_object();
	}

	[CCode (cname = "clutter_offscreen_effect_get_target_size")]
	public bool offscreen_effect_get_target_size(
		OffscreenEffect effect,
		out float width,
		out float height
	) {
		var response = GnomeShellRpc.GiStub.Runtime.call_values(
			"Clutter-OffscreenEffect.get_target_size", effect);
		var ret = response.retval.get_boolean();
		width = response.args.get(0).get_float();
		height = response.args.get(1).get_float();
		return ret;
	}

	[CCode (cname = "clutter_offscreen_effect_get_texture")]
	public Cogl.Texture offscreen_effect_get_texture(OffscreenEffect effect)
	{
		var response = GnomeShellRpc.GiStub.Runtime.call_values(
			"Clutter-OffscreenEffect.get_texture", effect);
		return (Cogl.Texture) response.retval.get_object();
	}

	[CCode (cname = "clutter_offscreen_effect_paint_target")]
	public void offscreen_effect_paint_target(
		OffscreenEffect effect,
		PaintNode node,
		PaintContext paint_context
	) {
		GLib.error("gi-stub: Clutter-OffscreenEffect.paint_target not wired");
	}
}
