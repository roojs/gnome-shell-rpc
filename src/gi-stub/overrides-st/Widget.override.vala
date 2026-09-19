		/**
		 * No lease construct here — {@code Actor.new} is denied and
		 * {@code Clutter.Actor}'s override parent-walks; {@code St-Widget}
		 * → {@code Helper-Actor.create}. {@code typeof(Widget)} would be
		 * the check if this class ever leased first.
		 *
		 * {@code signal_prefer=style_changed} split the GIR slot from the
		 * signal, so emit of {@code style-changed} does not run
		 * {@link style_changed_vfunc}. BaseIcon creates app textures in
		 * GJS {@code vfunc_style_changed}. Local connect only — do not
		 * {@link GnomeShellRpc.GiStub.Runtime.ensure_signal_subscribe}
		 * here (nested RPC mid-{@code .new} reply parse). Actor construct
		 * subscribes after mint for GJS {@code St.Bin} subclasses.
		 */
		construct {
			this.style_changed.connect(() => {
				this.style_changed_vfunc();
			});
		}
