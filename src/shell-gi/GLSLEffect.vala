/**
 * Owned {@code Shell.GLSLEffect} — leased compositor Helper-GLSLEffect (0.7.7 T-032).
 *
 * GJS subclasses implement {@link build_pipeline}; construct leases then calls it
 * so {@link add_glsl_snippet} RPCs land on the server pipeline.
 */
namespace Shell
{
	public class GLSLEffect : Clutter.OffscreenEffect, OLLMrpc.Live.Handle
	{
		public uint64 rpc_lid { get; set construct; default = 0; }

		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-GLSLEffect.create", null);
			this.rpc_lid = response.args.get(0).get_uint64();
			this.build_pipeline();
		}

		/**
		 * Stock virtual — GJS overrides as {@code vfunc_build_pipeline}.
		 */
		public virtual void build_pipeline()
		{
		}

		public void add_glsl_snippet(
			Cogl.SnippetHook hook,
			string declarations,
			string code,
			bool is_replace
		) {
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-GLSLEffect.add_glsl_snippet", this,
				OLLMrpc.args("issb", (int) hook, declarations, code, is_replace));
		}

		public int get_uniform_location(string name)
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-GLSLEffect.get_uniform_location", this,
				OLLMrpc.args("s", name));
			return response.retval.get_int();
		}

		public void set_uniform_float(
			int uniform,
			int n_components,
			float[] value
		) {
			var builder = new GLib.VariantBuilder(new GLib.VariantType("ad"));
			foreach (var f in value) {
				builder.add("d", (double) f);
			}
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-GLSLEffect.set_uniform_float", this,
				OLLMrpc.args("iiv", uniform, n_components, builder.end()));
		}

		public void set_uniform_matrix(
			int uniform,
			bool transpose,
			int dimensions,
			float[] value
		) {
			var builder = new GLib.VariantBuilder(new GLib.VariantType("ad"));
			foreach (var f in value) {
				builder.add("d", (double) f);
			}
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-GLSLEffect.set_uniform_matrix", this,
				OLLMrpc.args(
					"ibiiv", uniform, transpose, dimensions, value.length, builder.end()));
		}
	}
}
