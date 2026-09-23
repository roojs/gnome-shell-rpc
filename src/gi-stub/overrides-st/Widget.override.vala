		construct {
			this.signal_style_changed.connect(() => {
				this.style_changed_vfunc();
			});
		}

		void emit_style_changed_after_rpc()
		{
			this.signal_style_changed();
		}
