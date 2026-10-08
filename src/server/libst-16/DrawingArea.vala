/**
 * Sync {@code St.DrawingArea::repaint}. The client draws while
 * {@code in_repaint} is set, then {@link paint} copies the memfd
 * onto {@link global::St.DrawingArea.get_context} before the emission returns.
 */
namespace Gsr.Server.St
{
	public class DrawingArea : GLib.Object
	{
		private static Gee.HashMap<int, OLLMrpc.Live.Hook> repaint_hooks;

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-St-DrawingArea", typeof(DrawingArea),
				"create", "s",
				"add_hooks", "Sv",
				"watch_repaint", "t",
				"paint", "uuux",
				null
			);
			OLLMrpc.Request.register_live(
				"Gsr-St-DrawingArea", new DrawingArea());
		}

		/**
		 * ''Gsr-St-DrawingArea.create'' — peer for a JS
		 * {@code St.DrawingArea} subclass. Preferred-size vfuncs
		 * are installed by {@link add_hooks}. Stock
		 * {@code StDrawingArea.allocate} still sets the cairo size
		 * and emits {@code repaint}.
		 */
		public void create(OLLMrpc.Request request, string type_name)
		{
			var created = new DrawingAreaActor();
			created.client_type_name = type_name;
			request.reply(new OLLMrpc.Response() {
				args = OLLMrpc.args("t",
					(uint64) request.connection.export(created)),
			});
		}

		/**
		 * ''Gsr-St-DrawingArea.add_hooks'' — store preferred-size
		 * hooks on the leased {@link DrawingAreaActor}.
		 */
		public void add_hooks(
			OLLMrpc.Request request,
			string[] names,
			GLib.Variant vfunc_ids
		) {
			var created = request.connection.leases.get((int) request.lease_id)
				as DrawingAreaActor;
			if (created == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
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
				if (i >= names.length) {
					continue;
				}
				created.method_names.set(vfunc_id, names[i]);
			}
			request.reply(new OLLMrpc.Response() {
				args = OLLMrpc.args("v", ids.end()),
			});
		}

		/**
		 * ''Gsr-St-DrawingArea.watch_repaint'' — connect {@code repaint}
		 * on the leased drawing area. The handler {@code hook.emit}s
		 * and blocks until the client replies.
		 */
		public void watch_repaint(OLLMrpc.Request request, uint64 hook_id)
		{
			var area = request.connection.leases.get((int) request.lease_id)
				as global::St.DrawingArea;
			if (area == null || !request.connection.callbacks.has_key((int) hook_id)) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			if (DrawingArea.repaint_hooks == null) {
				DrawingArea.repaint_hooks = new Gee.HashMap<int, OLLMrpc.Live.Hook>();
			}
			var lid = (int) request.lease_id;
			if (DrawingArea.repaint_hooks.has_key(lid)) {
				request.reply(new OLLMrpc.Response());
				return;
			}
			var hook = request.connection.callbacks.get((int) hook_id);
			DrawingArea.repaint_hooks.set(lid, hook);
			area.repaint.connect(() => {
				hook.emit(OLLMrpc.args("t", hook.connection.export(area)));
			});
			request.reply(new OLLMrpc.Response());
		}

		/**
		 * ''Gsr-St-DrawingArea.paint'' — nested call from the client
		 * hook. Still inside the {@code repaint} emission, so
		 * {@code in_repaint} is set. Paint the memfd in the context's
		 * user space.
		 */
		public void paint(
			OLLMrpc.Request request,
			uint width,
			uint height,
			uint row_stride,
			int64 nbytes
		) {
			var area = request.connection.leases.get((int) request.lease_id)
				as global::St.DrawingArea;
			var got = request.buffer != null ? request.buffer.fd : -1;
			if (area == null || got < 0 || nbytes < 1 || width < 1 || height < 1) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var buf = new uint8[nbytes];
			Posix.lseek(got, 0, Posix.SEEK_SET);
			var nread = 0;
			while (nread < nbytes) {
				var n = Posix.read(got, (void*) &buf[nread], (size_t) (nbytes - nread));
				if (n <= 0) {
					break;
				}
				nread += (int) n;
			}
			if (nread != nbytes) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR);
				return;
			}
			var src = new Cairo.ImageSurface.for_data(
				buf, Cairo.Format.ARGB32, (int) width, (int) height, (int) row_stride);
			unowned Cairo.Context cr = area.get_context();
			cr.set_source_surface(src, 0, 0);
			cr.paint();
			cr.set_source_rgba(0, 0, 0, 0);
			request.reply(new OLLMrpc.Response());
		}
	}
}
