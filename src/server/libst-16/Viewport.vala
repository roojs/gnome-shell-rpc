/**
 * Lease for a JS {@code St.Viewport} subclass.
 */
namespace Gsr.Server.St
{
	public class Viewport : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-St-Viewport", typeof(Viewport),
				"create", "",
				"add_hooks", "Sv"
			);
			OLLMrpc.Request.register_live("Gsr-St-Viewport", new Viewport());
		}

		/**
		 * ''Gsr-St-Viewport.create'' — {@link ViewportActor} for a
		 * JS {@code St.Viewport} subclass.
		 */
		public void create(OLLMrpc.Request request)
		{
			var created = new ViewportActor();
			request.reply(new OLLMrpc.Response() {
				args = OLLMrpc.args("t",
					(uint64) request.connection.export(created)),
			});
		}

		/**
		 * ''Gsr-St-Viewport.add_hooks'' — store construct vfunc
		 * hooks on the leased {@link ViewportActor}.
		 */
		public void add_hooks(OLLMrpc.Request request, string[] names, GLib.Variant vfunc_ids)
		{
			var created = request.connection.leases.get((int) request.lease_id) as ViewportActor;
			if (created == null) {
				request.connection.reply_error(request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			 
			var ids = new GLib.VariantBuilder(new GLib.VariantType("at"));
			for (var i = 0; i <  (int) vfunc_ids.n_children(); i++) {
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
				if (i >= names.length) {
					continue;
				}
				created.method_names.set(vfunc_id, names[i]);
			}
			request.reply(new OLLMrpc.Response() {
				args = OLLMrpc.args("v", ids.end()),
			});
		}
	}
}
