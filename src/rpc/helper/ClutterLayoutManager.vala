/**
 * Helper-LayoutManager — mutter peer for a client GJS LayoutManager.
 * Class slots hook back to GJS {@code vfunc_*} (same split as Helper.Actor).
 *
 * @see docs/bugs/done/2026-09-16-allocate-follow-reference.md
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class LayoutManager : Clutter.LayoutManager
	{
		public Gee.HashMap<int, OLLMrpc.Live.Hook> vfuncs {
			get; set; default = new Gee.HashMap<int, OLLMrpc.Live.Hook>();
		}

		public static void rpc_register()
		{
			var helper = new LayoutManager();
			OLLMrpc.Request.add_class(
				"Helper-LayoutManager", typeof(LayoutManager),
				"create", "",
				"add_hook", "it",
				null);
			OLLMrpc.Request.register_live("Helper-LayoutManager", helper);
			LayoutManagerVfuncIds.register_vfunc_ids();
		}

		public void add_hook(
			OLLMrpc.Request request,
			int vfunc_id,
			uint64 hook_id
		) {
			var peer = request.connection.leases.get((int) request.lease_id)
				as LayoutManager;
			if (peer == null || !request.connection.callbacks.has_key((int) hook_id)) {
				request.connection.reply_error(request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			peer.vfuncs.set(vfunc_id, request.connection.callbacks.get((int) hook_id));
			request.reply(new OLLMrpc.Response());
		}

		public void create(OLLMrpc.Request request)
		{
			var created = new LayoutManager();
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", (uint64) request.connection.export(created)),
			});
		}

		public override void get_preferred_width(
			Clutter.Actor container,
			float for_height,
			out float min_width_p,
			out float nat_width_p
		) {
			min_width_p = 0.0f;
			nat_width_p = 0.0f;
			var hook = this.vfuncs.get(LayoutManagerVfuncIds.get_preferred_width_id);
			hook.emit(OLLMrpc.args("od", container, (double) for_height));
			var args = hook.reply_args;
			if ((args.size == 1 && args.get(0).holds(typeof(OLLMrpc.Error)))
					|| args.size < 2) {
				return;
			}
			min_width_p = (float) args.get(0).get_double();
			nat_width_p = (float) args.get(1).get_double();
		}

		public override void get_preferred_height(
			Clutter.Actor container,
			float for_width,
			out float min_height_p,
			out float nat_height_p
		) {
			min_height_p = 0.0f;
			nat_height_p = 0.0f;
			var hook = this.vfuncs.get(LayoutManagerVfuncIds.get_preferred_height_id);
			hook.emit(OLLMrpc.args("od", container, (double) for_width));
			var args = hook.reply_args;
			if ((args.size == 1 && args.get(0).holds(typeof(OLLMrpc.Error)))
					|| args.size < 2) {
				return;
			}
			min_height_p = (float) args.get(0).get_double();
			nat_height_p = (float) args.get(1).get_double();
			var helper = container as Actor;
			var parent = container.get_parent();
			GLib.debug("lm-preferred-height type=%s name=%s scale_y=%g min=%g nat=%g for=%g visible=%s mapped=%s parent=%s parent_visible=%s parent_mapped=%s",
				helper != null && helper.client_type_name != null
					? helper.client_type_name : container.get_type().name(),
				container.name != null ? container.name : "?",
				container.scale_y,
				min_height_p, nat_height_p, for_width,
				container.visible ? "1" : "0",
				container.is_mapped() ? "1" : "0",
				parent != null
					? (parent.name != null ? parent.name : parent.get_type().name())
					: "-",
				parent != null && parent.visible ? "1" : "0",
				parent != null && parent.is_mapped() ? "1" : "0");
		}

		public override void allocate(
			Clutter.Actor container,
			Clutter.ActorBox allocation
		) {
			var hook = this.vfuncs.get(LayoutManagerVfuncIds.allocate_id);
			hook.emit(OLLMrpc.args("odddd", container,
				(double) allocation.x1, (double) allocation.y1,
				(double) allocation.x2, (double) allocation.y2));
		}
	}
}
