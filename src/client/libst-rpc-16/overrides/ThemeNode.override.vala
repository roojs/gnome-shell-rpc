		/**
		 * Stock {@code st_theme_node_new}. The compositor builds the node.
		 * A theme argument uses the theme already installed on
		 * {@code context}. The client {@link Theme} is not itself a
		 * compositor object.
		 */
		public ThemeNode(
			ThemeContext context,
			ThemeNode? parent_node,
			Theme? theme,
			GLib.Type element_type,
			string? element_id,
			string? element_class,
			string? pseudo_class,
			string? inline_style
		) {
			Object();
			var type_name = element_type.name();
			if (type_name == null) {
				type_name = "";
			}
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-St-ThemeNode.create", null,
				OLLMrpc.args("oobsssss",
					context,
					parent_node,
					theme != null,
					type_name,
					element_id ?? "",
					element_class ?? "",
					pseudo_class ?? "",
					inline_style ?? ""));
			if (response.args.size < 1) {
				GLib.warning("St.ThemeNode: compositor did not create the node");
				return;
			}
			this.rpc_lid = response.args.get(0).get_uint64();
			Gsr.Client.Rpc.register_handle(this);
		}
