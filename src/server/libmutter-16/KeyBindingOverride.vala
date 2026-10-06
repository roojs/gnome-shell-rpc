/**
 * {@link global::Meta.KeyBinding} as name, modifiers, mask, builtin, reversed.
 *
 * {@code Shell.WM.filter-keybinding} otherwise writes the opaque box and
 * {@code StreamValue} resets the connection. The shell reads those five
 * through {@code get_name}, {@code get_modifiers}, {@code get_mask},
 * {@code is_builtin}, and {@code is_reversed}.
 */
namespace Gsr.Server.Meta
{
	public class KeyBindingOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get { return typeof(global::Meta.KeyBinding); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return OLLMrpc.args("suubb", "", (uint) 0, (uint) 0, false, false);
			}
			unowned var binding = (global::Meta.KeyBinding) src.get_boxed();
			var name = binding.get_name();
			return OLLMrpc.args("suubb", name != null ? name : "",
				(uint) binding.get_modifiers(), binding.get_mask(),
				binding.is_builtin(), binding.is_reversed());
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 5;
			return GLib.Value(typeof(global::Meta.KeyBinding));
		}
	}
}
