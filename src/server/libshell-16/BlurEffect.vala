/**
 * Helper-BlurEffect — compositor {@link Clutter.Effect} for client
 * {@link Shell.BlurEffect}.
 *
 * Stock {@code shell-blur-effect} paint path in Vala: offscreen layers,
 * {@link Clutter.BlurNode}, brightness snippet. Stage / Cogl context from
 * {@link bind} (no ShellGlobal).
 *
 * == Example ==
 *
 * {{{
 * Rpc.Helper.BlurEffect.bind(display);
 * // client: new Shell.BlurEffect() { radius = 30, mode = BACKGROUND };
 * }}}
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class BlurEffect : Clutter.Effect
	{
		private static Cogl.Context? cogl_context;

		private int priv_radius = 0;
		private float priv_brightness = 1f;
		/* 0 = actor, 1 = background — matches Shell.BlurMode. */
		private int priv_mode = 0;

		/**
		 * GObject props — client syncs via stock {@code Shell-BlurEffect.set_property}
		 * (no Helper setters).
		 */
		public int radius {
			get {
				return this.priv_radius;
			}
			set {
				if (this.priv_radius == value) {
					return;
				}
				this.priv_radius = value;
				this.queue_repaint();
			}
		}

		public float brightness {
			get {
				return this.priv_brightness;
			}
			set {
				if (this.priv_brightness == value) {
					return;
				}
				this.priv_brightness = value;
				this.queue_repaint();
			}
		}

		public int mode {
			get {
				return this.priv_mode;
			}
			set {
				if (this.priv_mode == value) {
					return;
				}
				this.priv_mode = value;
				if (value == 0) {
					this.background_texture = null;
					this.background_fb = null;
				}
				this.queue_repaint();
			}
		}

		private Cogl.Pipeline actor_pipeline;
		private Cogl.Pipeline background_pipeline;
		private Cogl.Pipeline brightness_pipeline;
		private int brightness_uniform = -1;

		private Cogl.Texture? actor_texture;
		private Cogl.Framebuffer? actor_fb;
		private Cogl.Texture? background_texture;
		private Cogl.Framebuffer? background_fb;
		private Cogl.Texture? brightness_texture;
		private Cogl.Framebuffer? brightness_fb;

		private uint tex_width;
		private uint tex_height;
		private float downscale_factor = 1f;

		public static void rpc_register()
		{
			OLLMrpc.Bin.register("Shell-BlurEffect", typeof(BlurEffect));
			OLLMrpc.Request.add_class(
				"Helper-BlurEffect", typeof(BlurEffect),
				"create", "",
				null
			);
		}

		public static void bind(Meta.Display display)
		{
			var stage = display.get_context().get_backend().get_stage();
			var clutter_ctx = ((Clutter.Actor) stage).get_context();
			cogl_context = clutter_ctx.get_backend().get_cogl_context();
			OLLMrpc.Request.register_live("Helper-BlurEffect", new BlurEffect());
		}

		construct {
			assert(cogl_context != null);
			var base_pipeline = new Cogl.Pipeline(cogl_context);
			base_pipeline.set_layer_null_texture(0);
			base_pipeline.set_layer_filters(
				0, Cogl.PipelineFilter.LINEAR, Cogl.PipelineFilter.LINEAR);
			base_pipeline.set_layer_wrap_mode(
				0, Cogl.PipelineWrapMode.CLAMP_TO_EDGE);
			this.actor_pipeline = base_pipeline.copy();
			this.background_pipeline = base_pipeline.copy();
			this.brightness_pipeline = base_pipeline.copy();
			this.brightness_pipeline.add_snippet(new Cogl.Snippet(
				Cogl.SnippetHook.FRAGMENT,
				"uniform float brightness;\n",
				"  cogl_color_out.rgb *= brightness;\n"));
			this.brightness_uniform =
				this.brightness_pipeline.get_uniform_location("brightness");
		}

		public override void set_actor(Clutter.Actor? actor)
		{
			base.set_actor(actor);
			this.actor_texture = null;
			this.actor_fb = null;
			this.background_texture = null;
			this.background_fb = null;
			this.brightness_texture = null;
			this.brightness_fb = null;
		}

		public override void paint_node(
			Clutter.PaintNode node,
			Clutter.PaintContext paint_context,
			Clutter.EffectPaintFlags flags
		) {
			var actor = this.get_actor();
			if (this.radius <= 0) {
				node.add_child(new Clutter.ActorNode(actor, -1));
				return;
			}

			var paint_opacity = this.mode == 1
				? (uint8) 255
				: actor.get_paint_opacity();

			var source_box = Clutter.ActorBox();
			if (this.mode == 0) {
				source_box = actor.get_allocation_box();
			} else {
				float origin_x;
				float origin_y;
				float width;
				float height;
				actor.get_transformed_position(out origin_x, out origin_y);
				actor.get_transformed_size(out width, out height);
				/* PaintContext has no StageView in the mutter VAPI — scale 1. */
				source_box.set_origin(origin_x, origin_y);
				source_box.set_size(width, height);
			}
			Clutter.ActorBox.clamp_to_pixel(ref source_box);

			float box_w;
			float box_h;
			source_box.get_size(out box_w, out box_h);
			var downscale = 1f;
			var scaled_w = box_w;
			var scaled_h = box_h;
			var scaled_radius = (float) this.radius;
			while (scaled_radius > 12f && scaled_w > 256f && scaled_h > 256f) {
				downscale *= 2f;
				scaled_w = box_w / downscale;
				scaled_h = box_h / downscale;
				scaled_radius = this.radius / downscale;
			}

			var fb_w = (uint) Math.floorf(box_w / downscale);
			var fb_h = (uint) Math.floorf(box_h / downscale);
			if (fb_w == 0 || fb_h == 0) {
				node.add_child(new Clutter.ActorNode(actor, -1));
				return;
			}

			this.actor_texture = new Cogl.Texture2D.with_size(
				cogl_context, (int) fb_w, (int) fb_h);
			this.actor_pipeline.set_layer_texture(0, this.actor_texture);
			this.actor_fb = new Cogl.Offscreen.with_texture(this.actor_texture);
			var actor_origin = Graphene.Point3D();
			actor_origin.init(-fb_w / 2f, -fb_h / 2f, 0f);
			var actor_proj = Graphene.Matrix();
			actor_proj.init_translate(actor_origin);
			actor_proj.scale(2f / fb_w, -2f / fb_h, 1f);
			this.actor_fb.set_projection_matrix(actor_proj);

			this.brightness_texture = new Cogl.Texture2D.with_size(
				cogl_context, (int) fb_w, (int) fb_h);
			this.brightness_pipeline.set_layer_texture(0, this.brightness_texture);
			this.brightness_fb = new Cogl.Offscreen.with_texture(
				this.brightness_texture);
			var bright_origin = Graphene.Point3D();
			bright_origin.init(-fb_w / 2f, -fb_h / 2f, 0f);
			var bright_proj = Graphene.Matrix();
			bright_proj.init_translate(bright_origin);
			bright_proj.scale(2f / fb_w, -2f / fb_h, 1f);
			this.brightness_fb.set_projection_matrix(bright_proj);

			if (this.mode == 1) {
				this.background_texture = new Cogl.Texture2D.with_size(
					cogl_context, (int) box_w, (int) box_h);
				this.background_pipeline.set_layer_texture(
					0, this.background_texture);
				this.background_fb = new Cogl.Offscreen.with_texture(
					this.background_texture);
				var bg_origin = Graphene.Point3D();
				bg_origin.init(-box_w / 2f, -box_h / 2f, 0f);
				var bg_proj = Graphene.Matrix();
				bg_proj.init_translate(bg_origin);
				bg_proj.scale(2f / box_w, -2f / box_h, 1f);
				this.background_fb.set_projection_matrix(bg_proj);
			}

			this.tex_width = (uint) box_w;
			this.tex_height = (uint) box_h;
			this.downscale_factor = downscale;

			var opacity = paint_opacity / 255f;
			var color = Cogl.Color();
			color.init_from_4f(opacity, opacity, opacity, opacity);
			this.brightness_pipeline.set_color(color);
			if (this.brightness_uniform > -1) {
				this.brightness_pipeline.set_uniform_1f(
					this.brightness_uniform, this.brightness);
			}

			float actor_w;
			float actor_h;
			actor.get_size(out actor_w, out actor_h);

			var brightness_node = new Clutter.LayerNode.to_framebuffer(
				this.brightness_fb, this.brightness_pipeline);
			node.add_child(brightness_node);
			var bright_box = Clutter.ActorBox();
			bright_box.set_size(actor_w, actor_h);
			brightness_node.add_rectangle(bright_box);

			var blur_node = new Clutter.BlurNode(
				(uint) (this.tex_width / this.downscale_factor),
				(uint) (this.tex_height / this.downscale_factor),
				this.radius / this.downscale_factor);
			brightness_node.add_child(blur_node);
			var blur_box = Clutter.ActorBox();
			blur_box.set_size(
				this.brightness_texture.get_width(),
				this.brightness_texture.get_height());
			blur_node.add_rectangle(blur_box);

			if (this.mode == 0) {
				var layer_node = new Clutter.LayerNode.to_framebuffer(
					this.actor_fb, this.actor_pipeline);
				blur_node.add_child(layer_node);
				var layer_box = Clutter.ActorBox();
				layer_box.set_size(this.tex_width / this.downscale_factor,
					this.tex_height / this.downscale_factor);
				layer_node.add_rectangle(layer_box);

				var transform = Graphene.Matrix();
				transform.init_scale(1f / this.downscale_factor, 1f / this.downscale_factor, 1f);
				var transform_node = new Clutter.TransformNode(transform);
				layer_node.add_child(transform_node);
				transform_node.add_child(new Clutter.ActorNode(actor, 255));
				return;
			}

			float transformed_x, transformed_y, transformed_width, transformed_height;
			source_box.get_origin(out transformed_x, out transformed_y);
			source_box.get_size(out transformed_width, out transformed_height);

			var background_node = new Clutter.LayerNode.to_framebuffer(
				this.background_fb, this.background_pipeline);
			blur_node.add_child(background_node);
			var bg_box = Clutter.ActorBox();
			bg_box.set_size(this.tex_width / this.downscale_factor,
				this.tex_height / this.downscale_factor);
			background_node.add_rectangle(bg_box);

			var blit_node = new Clutter.BlitNode(paint_context.get_framebuffer());
			background_node.add_child(blit_node);
			blit_node.add_blit_rectangle((int) transformed_x, (int) transformed_y,
				0, 0, (int) transformed_width, (int) transformed_height);

			node.add_child(new Clutter.ActorNode(actor, -1));
		}

		public void create(OLLMrpc.Request request)
		{
			var effect = new BlurEffect();
			var handle = (uint64) request.connection.export(effect);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}
	}
}
