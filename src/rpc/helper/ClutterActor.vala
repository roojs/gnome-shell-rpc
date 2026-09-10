/**
 * Layout relay for GJS {@code St.Widget} subclasses — same shape as
 * {@link Constraint}: mint hooks, sync {@link OLLMrpc.Live.Hook.emit}, apply.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Actor : global::St.Widget
	{
		public OLLMrpc.Live.Hook? preferred_width_hook;
		public OLLMrpc.Live.Hook? preferred_height_hook;
		public OLLMrpc.Live.Hook? allocate_hook;

		public static void rpc_register()
		{
			var helper = new Actor();
			OLLMrpc.Request.add_class(
				"Helper-Actor", typeof(Actor), "create", "ttt", null);
			OLLMrpc.Request.register_live("Helper-Actor", helper);
		}

		public override void get_preferred_width(
			float for_height,
			out float min_width_p,
			out float natural_width_p
		) {
			if (this.preferred_width_hook == null) {
				base.get_preferred_width(
					for_height, out min_width_p, out natural_width_p);
				return;
			}
			GLib.message(
				"DBG Helper.Actor.preferred_width emit BEGIN hook_id=%d",
				this.preferred_width_hook.id);
			this.preferred_width_hook.emit(OLLMrpc.args("td",
				this.preferred_width_hook.connection.export(this),
				(double) for_height));
			GLib.message(
				"DBG Helper.Actor.preferred_width emit END hook_id=%d reply_id=%d replied=%s",
				this.preferred_width_hook.id,
				this.preferred_width_hook.reply_id,
				this.preferred_width_hook.replied.to_string());
			if (this.preferred_width_hook.reply_args.size < 2) {
				base.get_preferred_width(
					for_height, out min_width_p, out natural_width_p);
				return;
			}
			min_width_p = (float) this.preferred_width_hook.reply_args
				.get(0).get_double();
			natural_width_p = (float) this.preferred_width_hook.reply_args
				.get(1).get_double();
		}

		public override void get_preferred_height(
			float for_width,
			out float min_height_p,
			out float natural_height_p
		) {
			if (this.preferred_height_hook == null) {
				base.get_preferred_height(
					for_width, out min_height_p, out natural_height_p);
				return;
			}
			GLib.message(
				"DBG Helper.Actor.preferred_height emit BEGIN hook_id=%d",
				this.preferred_height_hook.id);
			this.preferred_height_hook.emit(OLLMrpc.args("td",
				this.preferred_height_hook.connection.export(this),
				(double) for_width));
			GLib.message(
				"DBG Helper.Actor.preferred_height emit END hook_id=%d reply_id=%d replied=%s",
				this.preferred_height_hook.id,
				this.preferred_height_hook.reply_id,
				this.preferred_height_hook.replied.to_string());
			if (this.preferred_height_hook.reply_args.size < 2) {
				base.get_preferred_height(
					for_width, out min_height_p, out natural_height_p);
				return;
			}
			min_height_p = (float) this.preferred_height_hook.reply_args
				.get(0).get_double();
			natural_height_p = (float) this.preferred_height_hook.reply_args
				.get(1).get_double();
		}

		public override void allocate(Clutter.ActorBox box)
		{
			if (this.allocate_hook == null) {
				base.allocate(box);
				return;
			}
			GLib.message(
				"DBG Helper.Actor.allocate emit BEGIN hook_id=%d box=(%.1f,%.1f)-(%.1f,%.1f)",
				this.allocate_hook.id, box.x1, box.y1, box.x2, box.y2);
			this.allocate_hook.emit(OLLMrpc.args("tdddd",
				this.allocate_hook.connection.export(this),
				(double) box.x1, (double) box.y1,
				(double) box.x2, (double) box.y2));
			GLib.message(
				"DBG Helper.Actor.allocate emit END hook_id=%d reply_id=%d replied=%s args=%d",
				this.allocate_hook.id,
				this.allocate_hook.reply_id,
				this.allocate_hook.replied.to_string(),
				this.allocate_hook.reply_args.size);
			if (this.allocate_hook.reply_args.size >= 1
					&& this.allocate_hook.reply_args.get(0).type()
						== GLib.Type.BOOLEAN
					&& this.allocate_hook.reply_args.get(0).get_boolean()) {
				base.allocate(box);
				return;
			}
			this.set_allocation(box);
		}

		public void create(
			OLLMrpc.Request request,
			uint64 preferred_width_cb,
			uint64 preferred_height_cb,
			uint64 allocate_cb
		) {
			if (!request.connection.callbacks.has_key((int) preferred_width_cb)
					|| !request.connection.callbacks.has_key(
						(int) preferred_height_cb)
					|| !request.connection.callbacks.has_key(
						(int) allocate_cb)) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var created = new Actor();
			created.preferred_width_hook =
				request.connection.callbacks.get((int) preferred_width_cb);
			created.preferred_height_hook =
				request.connection.callbacks.get((int) preferred_height_cb);
			created.allocate_hook =
				request.connection.callbacks.get((int) allocate_cb);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t",
					(uint64) request.connection.export(created)),
			});
		}
	}
}
