/**
 * Layout relay for GJS {@code St.Widget} subclasses ({@code UiActor},
 * {@code Panel}, …). Mint with live hooks like {@link Constraint}.
 *
 * Allocate hooks run from a server {@link GLib.Idle} that re-enters
 * {@link allocate} (so {@code set_allocation} stays inside the vfunc).
 * Deferral avoids emitting during the client's {@code call_sync} that
 * triggered layout. Preferred uses the StWidget base on the server.
 *
 * Extends stock {@code StWidget} via {@code st-widget-peer.vapi}.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	/* global::St — not Helper.St (Ffi mint class in this namespace). */
	public class Actor : global::St.Widget
	{
		public OLLMrpc.Live.Hook? preferred_width_hook;
		public OLLMrpc.Live.Hook? preferred_height_hook;
		public OLLMrpc.Live.Hook? allocate_hook;

		private Clutter.ActorBox pending_allocate;
		private bool allocate_idle_queued;
		private bool in_allocate_hook_emit;

		public static void rpc_register()
		{
			var helper = new Actor();
			OLLMrpc.Request.add_class(
				"Helper-Actor", typeof(Actor),
				"create", "ttt",
				"chain_get_preferred_width", "f",
				"chain_get_preferred_height", "f",
				"chain_allocate", "ay",
				null
			);
			OLLMrpc.Request.register_live("Helper-Actor", helper);
		}

		public override void get_preferred_width(
			float for_height,
			out float min_width_p,
			out float natural_width_p
		) {
			base.get_preferred_width(
				for_height, out min_width_p, out natural_width_p);
		}

		public override void get_preferred_height(
			float for_width,
			out float min_height_p,
			out float natural_height_p
		) {
			base.get_preferred_height(
				for_width, out min_height_p, out natural_height_p);
		}

		public override void allocate(Clutter.ActorBox box)
		{
			if (this.allocate_hook == null) {
				base.allocate(box);
				return;
			}
			if (this.in_allocate_hook_emit) {
				this.allocate_hook.emit(OLLMrpc.args("tdddd",
					this.allocate_hook.connection.export(this),
					(double) box.x1, (double) box.y1,
					(double) box.x2, (double) box.y2));
				if (this.allocate_hook.reply_args.size >= 1
						&& this.allocate_hook.reply_args.get(0).type()
							== GLib.Type.BOOLEAN
						&& this.allocate_hook.reply_args.get(0).get_boolean()) {
					base.allocate(box);
					return;
				}
				this.set_allocation(box);
				return;
			}
			/* Sync pass: stock layout so add_child can finish. */
			base.allocate(box);
			this.pending_allocate = box;
			if (this.allocate_idle_queued) {
				return;
			}
			this.allocate_idle_queued = true;
			GLib.Idle.add(() => {
				this.allocate_idle_queued = false;
				this.in_allocate_hook_emit = true;
				this.allocate(this.pending_allocate);
				this.in_allocate_hook_emit = false;
				return GLib.Source.REMOVE;
			});
		}

		/**
		 * {@code Helper-Actor.create} — mint relay + three layout hooks.
		 */
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
			var handle = (uint64) request.connection.export(created);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}

		public void chain_get_preferred_width(
			OLLMrpc.Request request,
			double for_height
		) {
			var self = (Actor) request.connection.leases.get(
				(int) request.lease_id);
			float min = 0.0f, nat = 0.0f;
			self.get_preferred_width(
				(float) for_height, out min, out nat);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("dd", (double) min, (double) nat),
			});
		}

		public void chain_get_preferred_height(
			OLLMrpc.Request request,
			double for_width
		) {
			var self = (Actor) request.connection.leases.get(
				(int) request.lease_id);
			float min = 0.0f, nat = 0.0f;
			self.get_preferred_height(
				(float) for_width, out min, out nat);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("dd", (double) min, (double) nat),
			});
		}

		public void chain_allocate(
			OLLMrpc.Request request,
			GLib.Bytes box_bytes
		) {
			var self = (Actor) request.connection.leases.get(
				(int) request.lease_id);
			Clutter.ActorBox box = *((Clutter.ActorBox*) box_bytes.get_data());
			var saved = self.allocate_hook;
			self.allocate_hook = null;
			self.allocate(box);
			self.allocate_hook = saved;
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
