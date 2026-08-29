/**
 * Client entry for {@code clutter_shader_effect_set_uniform} (plan 0.7.2 D).
 *
 * Varargs C ABI cannot be generated; {@link c-clutter-st-abi-gaps.c} packs
 * values and calls {@link set_uniform_packed}, which RPCs to the Helper.
 */
namespace GnomeShellRpc.GiStub
{
	public class ShaderEffectUniform : GLib.Object
	{
		/**
		 * Pack uniforms onto {@code Helper-ShaderEffect.set_uniform}.
		 *
		 * @param effect leased stub ShaderEffect
		 * @param name uniform name
		 * @param type_name {@link GLib.Type.name} of the GIR gtype
		 * @param values floats (ints widened); length is component count
		 */
		[CCode (cname = "gsr_clutter_shader_effect_set_uniform")]
		public static void set_uniform_packed(
			GLib.Object effect,
			string name,
			string type_name,
			[CCode (array_length_pos = 3.9)] float[] values
		) {
			var builder = new GLib.VariantBuilder(new GLib.VariantType("af"));
			foreach (var f in values) {
				builder.add("f", f);
			}
			Runtime.call_values(
				"Helper-ShaderEffect.set_uniform", effect,
				OLLMrpc.args("ssv", name, type_name, builder.end()));
		}
	}
}
