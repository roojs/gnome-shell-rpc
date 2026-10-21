/**
 * JS {@code St.Viewport} subclass. {@code StScrollable}, so
 * {@code St.ScrollView.set_child} accepts it. {@code allocate}
 * emits the client hook. A chain reply runs stock
 * {@code St.Viewport.allocate}.
 */
namespace Gsr.Server.St
{
	public class ViewportActor : global::St.Viewport
	{
		public Gee.HashMap<int, OLLMrpc.Live.Hook> vfuncs {
			get; set; default = new Gee.HashMap<int, OLLMrpc.Live.Hook>();
		}
		public Gee.HashMap<int, string> method_names {
			get; set; default = new Gee.HashMap<int, string>();
		}
		static int allocate_id;

		public static void rpc_register()
		{
			allocate_id = OLLMrpc.Gi.vfunc_offset(
				"Clutter", "Actor", "allocate");
		}

		/**
		 * Client hook, then stock viewport allocate when the
		 * reply asks to chain. An empty reply chains too.
		 */
		public override void allocate(global::Clutter.ActorBox box)
		{
			var hook = this.vfuncs.get(allocate_id);
			if (hook == null) {
				base.allocate(box);
				return;
			}
			hook.emit(OLLMrpc.args("tdddd",
				hook.connection.export(this),
				(double) box.x1, (double) box.y1,
				(double) box.x2, (double) box.y2));
			var reply = hook.reply_args;
			if (reply.size >= 1
					&& !(reply.get(0).type() == GLib.Type.BOOLEAN
						&& reply.get(0).get_boolean())) {
				return;
			}
			var saved = this.vfuncs;
			this.vfuncs = new Gee.HashMap<int, OLLMrpc.Live.Hook>();
			base.allocate(box);
			this.vfuncs = saved;
		}
	}
}
