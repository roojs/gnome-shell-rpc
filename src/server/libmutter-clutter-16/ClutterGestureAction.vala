/**
 * Clutter GestureAction peer for a client GJS subclass.
 * Class slots hook back to the client's real Clutter vfunc overrides.
 */
namespace Gsr.Server.Clutter
{
	public class GestureAction : global::Clutter.GestureAction
	{
		public Gee.HashMap<int, OLLMrpc.Live.Hook> vfuncs {
			get; set; default = new Gee.HashMap<int, OLLMrpc.Live.Hook>();
		}

		public static void rpc_register()
		{
			var helper = new GestureAction();
			OLLMrpc.Request.add_class(
				"Gsr-Clutter-GestureAction", typeof(GestureAction),
				"create", "",
				"add_hooks", "v",
				null);
			OLLMrpc.Request.register_live("Gsr-Clutter-GestureAction", helper);
			GestureActionVfuncIds.register_vfunc_ids();
		}

		public void create(OLLMrpc.Request request)
		{
			var created = new GestureAction();
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", (uint64) request.connection.export(created)),
			});
		}

		public void add_hooks(OLLMrpc.Request request, GLib.Variant vfunc_ids)
		{
			var created = request.connection.leases.get((int) request.lease_id) as GestureAction;
			if (created == null) {
				request.connection.reply_error(request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var n = (int) vfunc_ids.n_children();
			var ids = new GLib.VariantBuilder(new GLib.VariantType("at"));
			for (var i = 0; i < n; i++) {
				var id = request.connection.next_handle;
				request.connection.next_handle++;
				var hook = new OLLMrpc.Live.Hook() {
					connection = request.connection,
					id = id
				};
				request.connection.callbacks.set(id, hook);
				ids.add("t", (uint64) id);
				var vfunc_id = vfunc_ids.get_child_value(i).get_int32();
				created.vfuncs.set(vfunc_id, hook);
			}
			request.reply(new OLLMrpc.Response() {
				args = OLLMrpc.args("v", ids.end()),
			});
		}

		public override bool gesture_begin(global::Clutter.Actor actor)
		{
			var hook = this.vfuncs.get(GestureActionVfuncIds.gesture_begin_id);
			if (hook == null) {
				return base.gesture_begin(actor);
			}
			hook.emit(OLLMrpc.args("o", actor));
			if (hook.reply_args.size < 1) {
				return false;
			}
			return hook.reply_args.get(0).get_boolean();
		}

		public override bool gesture_progress(global::Clutter.Actor actor)
		{
			var hook = this.vfuncs.get(GestureActionVfuncIds.gesture_progress_id);
			if (hook == null) {
				return base.gesture_progress(actor);
			}
			hook.emit(OLLMrpc.args("o", actor));
			if (hook.reply_args.size < 1) {
				return false;
			}
			return hook.reply_args.get(0).get_boolean();
		}

		public override void gesture_end(global::Clutter.Actor actor)
		{
			var hook = this.vfuncs.get(GestureActionVfuncIds.gesture_end_id);
			if (hook == null) {
				return;
			}
			hook.emit(OLLMrpc.args("o", actor));
		}

		public override void gesture_cancel(global::Clutter.Actor actor)
		{
			var hook = this.vfuncs.get(GestureActionVfuncIds.gesture_cancel_id);
			if (hook == null) {
				return;
			}
			hook.emit(OLLMrpc.args("o", actor));
		}

		public override bool gesture_prepare(global::Clutter.Actor actor)
		{
			var hook = this.vfuncs.get(GestureActionVfuncIds.gesture_prepare_id);
			if (hook == null) {
				return base.gesture_prepare(actor);
			}
			hook.emit(OLLMrpc.args("o", actor));
			if (hook.reply_args.size < 1) {
				return false;
			}
			return hook.reply_args.get(0).get_boolean();
		}
	}
}
