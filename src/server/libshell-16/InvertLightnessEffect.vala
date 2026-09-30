/**
 * Helper-InvertLightnessEffect — compositor OffscreenEffect for client
 * {@link Shell.InvertLightnessEffect}.
 *
 * Stock {@code shell-invert-lightness-effect}: lightness invert GLSL on
 * texture lookup. Stage / Cogl context from {@link bind}.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class InvertLightnessEffect : Clutter.OffscreenEffect
	{
		private static Cogl.Context? cogl_context;
		private static Cogl.Pipeline? base_pipeline;
		private Cogl.Pipeline pipeline;

		public static void rpc_register()
		{
			OLLMrpc.Bin.register("Shell-InvertLightnessEffect",
				typeof(InvertLightnessEffect));
			OLLMrpc.Request.add_class(
				"Helper-InvertLightnessEffect", typeof(InvertLightnessEffect),
				"create", "",
				null
			);
		}

		public static void bind(Meta.Display display)
		{
			var stage = display.get_context().get_backend().get_stage();
			var clutter_ctx = ((Clutter.Actor) stage).get_context();
			cogl_context = clutter_ctx.get_backend().get_cogl_context();
			OLLMrpc.Request.register_live("Helper-InvertLightnessEffect",
				new InvertLightnessEffect());
		}

		construct {
			assert(cogl_context != null);
			if (base_pipeline == null) {
				base_pipeline = new Cogl.Pipeline(cogl_context);
				var snippet = new Cogl.Snippet(
					Cogl.SnippetHook.TEXTURE_LOOKUP, null, null);
				snippet.set_replace("""
cogl_texel = texture2D (cogl_sampler, cogl_tex_coord.st);
vec3 effect = vec3 (cogl_texel);

float maxColor = max (cogl_texel.r, max (cogl_texel.g, cogl_texel.b));
float minColor = min (cogl_texel.r, min (cogl_texel.g, cogl_texel.b));
float lightness = (maxColor + minColor) / 2.0;

float delta = (1.0 - lightness) - lightness;
effect.rgb = (effect.rgb + delta);

cogl_texel = vec4 (effect, cogl_texel.a);
""");
				base_pipeline.add_layer_snippet(0, snippet);
				base_pipeline.set_layer_null_texture(0);
			}
			this.pipeline = base_pipeline.copy();
		}

		public override unowned Cogl.Pipeline create_pipeline(Cogl.Texture texture)
		{
			this.pipeline.set_layer_texture(0, texture);
			this.pipeline.@ref();
			return this.pipeline;
		}

		public void create(OLLMrpc.Request request)
		{
			var effect = new InvertLightnessEffect();
			var handle = (uint64) request.connection.export(effect);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}
	}
}
