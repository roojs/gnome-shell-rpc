		/**
		 * Fallback lease for JS {@code extends Clutter.Constraint}
		 * ({@code layout.js} {@code MonitorConstraint}, Overview / OSD / …).
		 *
		 * Vala {@code construct} runs derived → base. Stock leaves
		 * ({@link BindConstraint}, {@link AlignConstraint}, {@link SnapConstraint})
		 * lease via their own {@code *.new} first. This runs only when
		 * {@code rpc_lid} is still zero.
		 *
		 * Server peer is {@code Helper-Constraint.create} →
		 * {@code ConstraintRelay}: allocation {@code Hook.emit}s so the
		 * client GJS {@code vfunc_update_allocation} runs and returns the box
		 * (same Live.Callback splice as IdleMonitor / Window foreach).
		 */
		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			if (!this.get_type().is_a(typeof(Constraint))) {
				return;
			}
			var self = this;
			var callback_id = GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
				var actor = (Actor) GnomeShellRpc.GiStub.Runtime.client.proxies.get(
					(int) call.args.get(0).get_uint64());
				var box = ActorBox();
				box.x1 = (float) call.args.get(1).get_double();
				box.y1 = (float) call.args.get(2).get_double();
				box.x2 = (float) call.args.get(3).get_double();
				box.y2 = (float) call.args.get(4).get_double();
				self.update_allocation(actor, box);
				return OLLMrpc.args("dddd",
					(double) box.x1, (double) box.y1,
					(double) box.x2, (double) box.y2);
			});
			var response = GnomeShellRpc.call_value(
				"Helper-Constraint.create",
				null,
				OLLMrpc.args("t", callback_id));
			this.rpc_lid = response.args.get(0).get_uint64();
		}
