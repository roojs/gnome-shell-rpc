	/**
	 * Varargs {@code clutter_shader_effect_set_uniform} cannot be generated.
	 * {@link c-clutter-abi.c} unpacks the values and calls this.
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
		Gsr.Client.Rpc.call_value("Gsr-Clutter-ShaderEffect.set_uniform", effect,
			OLLMrpc.args("ssv", name, type_name, builder.end()));
	}
