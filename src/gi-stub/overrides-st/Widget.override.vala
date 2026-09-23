		/*
		 * TEMPORARY: Vala's virtual signal does not install GJS
		 * vfunc_style_changed. The generator therefore keeps the signal and
		 * stock-offset virtual method separate for this proven exception.
		 */
		construct {
			this.signal_style_changed.connect(() => {
				this.style_changed_vfunc();
			});
		}

		void emit_style_changed_after_rpc()
		{
			this.signal_style_changed();
		}
