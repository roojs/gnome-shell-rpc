		/**
		 * Stock {@code meta_keymap_description_new_from_rules}.
		 * {@code display_names} and {@code short_names} are the
		 * per-layout lists. The other four arguments are strings.
		 *
		 * @param model xkb model
		 * @param layout comma-joined layouts
		 * @param variant comma-joined variants
		 * @param options xkb options string
		 * @param display_names one display name per layout
		 * @param short_names one short name per layout
		 */
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
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-Keymap.new_from_rules",
				null,
				OLLMrpc.args(
					"ssssasas",
					model, layout, variant, options,
					display_names, short_names));
			this.rpc_lid = response.args.get(0).get_uint64();
		}

		/**
		 * Stock {@code meta_keymap_description_is_locked}.
		 *
		 * @return whether the compositor locked this description
		 */
		[CCode (cname = "gsr_meta_keymap_description_is_locked")]
		public bool is_locked()
		{
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-Keymap.is_locked", this);
			return response.retval.get_boolean();
		}

		/**
		 * Stock {@code meta_keymap_description_direct_equal}.
		 *
		 * @param other description to compare
		 * @return whether the compositor treats them as the same rules
		 */
		[CCode (cname = "gsr_meta_keymap_description_direct_equal")]
		public bool direct_equal(KeymapDescription other)
		{
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-Keymap.direct_equal",
				this,
				OLLMrpc.args("t", other.rpc_lid));
			return response.retval.get_boolean();
		}
