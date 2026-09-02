/**
 * Helper-GLSLEffect — compositor OffscreenEffect for Shell.GLSLEffect.
 *
 * Client leases one of these and drives snippets via build_pipeline RPC.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class GLSLEffect : Clutter.OffscreenEffect
	{
		private static Cogl.Context? cogl_context;
		private Cogl.Pipeline pipeline;

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-GLSLEffect", typeof(GLSLEffect),
				"create", "",
				"add_glsl_snippet", "issb",
				"get_uniform_location", "s",
				"set_uniform_float", "iiv",
				"set_uniform_matrix", "ibiiv",
				null
			);
		}

		public static void bind(Meta.Display display)
		{
			var stage = display.get_context().get_backend().get_stage();
			var clutter_ctx = ((Clutter.Actor) stage).get_context();
			cogl_context = clutter_ctx.get_backend().get_cogl_context();
			OLLMrpc.Request.register_live("Helper-GLSLEffect", new GLSLEffect());
			OLLMrpc.Bin.register_alias("Shell-GLSLEffect", typeof(GLSLEffect));
		}

		construct {
			assert(cogl_context != null);
			this.pipeline = new Cogl.Pipeline(cogl_context);
			try {
				this.pipeline.set_blend(
					"RGB = ADD (SRC_COLOR * (SRC_COLOR[A]), DST_COLOR * (1-SRC_COLOR[A]))");
			} catch (GLib.Error e) {
				GLib.warning("GLSLEffect: set_blend failed: %s", e.message);
			}
			this.pipeline.set_layer_null_texture(0);
		}

		public override unowned Cogl.Pipeline create_pipeline(Cogl.Texture texture)
		{
			this.pipeline.set_layer_texture(0, texture);
			this.pipeline.@ref();
			return this.pipeline;
		}

		public void create(OLLMrpc.Request request)
		{
			var effect = new GLSLEffect();
			var handle = (uint64) request.connection.export(effect);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}

		public void add_glsl_snippet(
			OLLMrpc.Request request,
			int hook,
			string declarations,
			string code,
			bool is_replace
		) {
			var effect = (GLSLEffect) request.connection.leases.get(
				(int) request.lease_id
			);
			var snippet_hook = (Cogl.SnippetHook) hook;
			Cogl.Snippet snippet;
			if (is_replace) {
				snippet = new Cogl.Snippet(snippet_hook, declarations, null);
				snippet.set_replace(code);
			} else {
				snippet = new Cogl.Snippet(snippet_hook, declarations, code);
			}
			if (snippet_hook == Cogl.SnippetHook.VERTEX
					|| snippet_hook == Cogl.SnippetHook.FRAGMENT) {
				effect.pipeline.add_snippet(snippet);
			} else {
				effect.pipeline.add_layer_snippet(0, snippet);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		public void get_uniform_location(
			OLLMrpc.Request request,
			string name
		) {
			var effect = (GLSLEffect) request.connection.leases.get(
				(int) request.lease_id
			);
			var response = new OLLMrpc.Response() {
				id = request.id,
			};
			response.retval = GLib.Value(typeof(int));
			response.retval.set_int(effect.pipeline.get_uniform_location(name));
			request.reply(response);
		}

		public void set_uniform_float(
			OLLMrpc.Request request,
			int uniform,
			int n_components,
			GLib.Variant floats_v
		) {
			var effect = (GLSLEffect) request.connection.leases.get(
				(int) request.lease_id
			);
			var n = (int) floats_v.n_children();
			var floats = new float[n];
			for (var i = 0; i < n; i++) {
				floats[i] = (float) floats_v.get_child_value(i).get_double();
			}
			effect.pipeline.set_uniform_float(
				uniform, n_components, n / n_components, floats);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		public void set_uniform_matrix(
			OLLMrpc.Request request,
			int uniform,
			bool transpose,
			int dimensions,
			int total_count,
			GLib.Variant floats_v
		) {
			var effect = (GLSLEffect) request.connection.leases.get(
				(int) request.lease_id
			);
			var n = (int) floats_v.n_children();
			var floats = new float[n];
			for (var i = 0; i < n; i++) {
				floats[i] = (float) floats_v.get_child_value(i).get_double();
			}
			var count = n / (dimensions * dimensions);
			effect.pipeline.set_uniform_matrix(
				uniform, dimensions, count, transpose, floats);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
