		/*
		 * TEMPORARY: St.overrides emits signal_style_changed() after each
		 * style-mutating RPC returns. Do not subscribe here or emit from a
		 * Live.Invoke: either path re-enters libgjs from call_poll() and
		 * SIGSEGVs. Remove this note with those local_emit_after overrides.
		 */
