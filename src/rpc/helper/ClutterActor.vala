/**
 * Layout relay for GJS {@code St.Widget} subclasses — same shape as
 * {@link Constraint}: mint hooks, sync {@link OLLMrpc.Live.Hook.emit}, apply.
 *
 * {@link LayoutHooks} owns emit + JS sizes. Empty / chain reply: {@link Actor}
 * pops {@link Actor.layout_hooks}, calls {@code base} (not the vfunc), pulls.
 *
 * 🚫 Do not revive emit_guard / {@code suppress_emit}.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class LayoutHooks
	{
		public OLLMrpc.Live.Hook preferred_width;
		public OLLMrpc.Live.Hook preferred_height;
		public OLLMrpc.Live.Hook allocate;

		/**
		 * Emit preferred-width hook. {@code true} = JS sizes in outs;
		 * {@code false} = chain / empty — caller runs {@code base}.
		 */
		public bool measure_width(
			Actor actor,
			float for_height,
			out float min_width_p,
			out float natural_width_p
		) {
			/* Drop prior JS sizes — emit only sets replied=false; stale
			 * reply_args would look like a JS reply without a matching Invoke. */
			this.preferred_width.reply_args.clear();
			this.preferred_width.emit(OLLMrpc.args("td",
				this.preferred_width.connection.export(actor),
				(double) for_height));
			if (this.preferred_width.reply_args.size < 2) {
				min_width_p = 0.0f;
				natural_width_p = 0.0f;
				return false;
			}
			min_width_p = (float) this.preferred_width.reply_args
				.get(0).get_double();
			natural_width_p = (float) this.preferred_width.reply_args
				.get(1).get_double();
			return true;
		}

		/**
		 * Emit preferred-height hook. {@code true} = JS sizes; {@code false} =
		 * caller runs {@code base}.
		 */
		public bool measure_height(
			Actor actor,
			float for_width,
			out float min_height_p,
			out float natural_height_p
		) {
			this.preferred_height.reply_args.clear();
			this.preferred_height.emit(OLLMrpc.args("td",
				this.preferred_height.connection.export(actor),
				(double) for_width));
			if (this.preferred_height.reply_args.size < 2) {
				min_height_p = 0.0f;
				natural_height_p = 0.0f;
				return false;
			}
			min_height_p = (float) this.preferred_height.reply_args
				.get(0).get_double();
			natural_height_p = (float) this.preferred_height.reply_args
				.get(1).get_double();
			return true;
		}

		/**
		 * Emit allocate hook. {@code true} = JS applied (or set_allocation);
		 * {@code false} = chain / empty — caller runs {@code base.allocate}.
		 */
		public bool measure_allocate(Actor actor, Clutter.ActorBox box)
		{
			this.allocate.reply_args.clear();
			this.allocate.emit(OLLMrpc.args("tdddd",
				this.allocate.connection.export(actor),
				(double) box.x1, (double) box.y1,
				(double) box.x2, (double) box.y2));
			if (this.allocate.reply_args.size < 1) {
				return false;
			}
			var chain = this.allocate.reply_args.get(0).type()
					== GLib.Type.BOOLEAN
				&& this.allocate.reply_args.get(0).get_boolean();
			if (chain) {
				return false;
			}
			actor.set_allocation(box);
			return true;
		}
	}

	public class Actor : global::St.Widget
	{
		public LayoutHooks? layout_hooks;

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
			var hooks = this.layout_hooks;
			if (hooks == null) {
				base.get_preferred_width(
					for_height, out min_width_p, out natural_width_p);
				return;
			}
			if (hooks.measure_width(
					this, for_height, out min_width_p, out natural_width_p)) {
				return;
			}
			/* Pop before base — must use base., not vfunc (infinite recurse). */
			this.layout_hooks = null;
			base.get_preferred_width(for_height, out min_width_p, out natural_width_p);
			this.layout_hooks = hooks;
		}

		public override void get_preferred_height(
			float for_width,
			out float min_height_p,
			out float natural_height_p
		) {
			var hooks = this.layout_hooks;
			if (hooks == null) {
				base.get_preferred_height(
					for_width, out min_height_p, out natural_height_p);
				return;
			}
			if (hooks.measure_height(
					this, for_width, out min_height_p, out natural_height_p)) {
				return;
			}
			this.layout_hooks = null;
			base.get_preferred_height(
				for_width, out min_height_p, out natural_height_p);
			this.layout_hooks = hooks;
		}

		public override void allocate(Clutter.ActorBox box)
		{
			var hooks = this.layout_hooks;
			if (hooks == null) {
				base.allocate(box);
				return;
			}
			if (hooks.measure_allocate(this, box)) {
				return;
			}
			this.layout_hooks = null;
			base.allocate(box);
			this.layout_hooks = hooks;
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
			created.layout_hooks = new LayoutHooks() {
				preferred_width = request.connection.callbacks.get(
					(int) preferred_width_cb),
				preferred_height = request.connection.callbacks.get(
					(int) preferred_height_cb),
				allocate = request.connection.callbacks.get((int) allocate_cb),
			};
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t",
					(uint64) request.connection.export(created)),
			});
		}
	}
}
