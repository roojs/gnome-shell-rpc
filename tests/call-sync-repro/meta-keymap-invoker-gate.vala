namespace MetaKeymapInvokerGate
{
	public class KeymapDescription : GLib.Object
	{
		[CCode (cname = "gsr_meta_keymap_description_new_from_rules")]
		public KeymapDescription.new_from_rules(
			string model,
			string layout,
			string variant,
			string options,
			[CCode (array_length = false, array_null_terminated = true)]
			string[] display_names,
			[CCode (array_length = false, array_null_terminated = true)]
			string[] short_names
		) {
		}
	}
}
