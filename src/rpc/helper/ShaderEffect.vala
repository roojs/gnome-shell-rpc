/**
 * Delivers {@link Clutter.ShaderEffect} uniform RPC (plan 0.7.2 D).
 *
 * Wire prefix ''Helper-ShaderEffect''. Lease is the effect. Client packs
 * varargs into floats + type name; {@code gsr_helper_apply_shader_uniform}
 * rebuilds a {@link GLib.Value} on the compositor.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class ShaderEffect : GLib.Object
	{
		[CCode (cname = "gsr_helper_apply_shader_uniform")]
		private static extern void apply_uniform(
			Clutter.ShaderEffect effect,
			string name,
			string type_name,
			[CCode (array_length = false)] float[] floats,
			int n_values
		);

		public static void register()
		{
			OLLMrpc.Request.add_class(
				"Helper-ShaderEffect", typeof(ShaderEffect),
				"set_uniform", "ssv",
				null
			);
			OLLMrpc.Request.register_live("Helper-ShaderEffect",
				new ShaderEffect());
		}

		public void set_uniform(
			OLLMrpc.Request request,
			string name,
			string type_name,
			GLib.Variant floats_v
		) {
			var effect = (Clutter.ShaderEffect) request.connection.leases.get(
				(int) request.lease_id);
			var n = (int) floats_v.n_children();
			var floats = new float[n];
			for (var i = 0; i < n; i++) {
				floats[i] = (float) floats_v.get_child_value(i).get_double();
			}
			apply_uniform(effect, name, type_name, floats, n);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
