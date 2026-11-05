/**
 * Server peer for {@link global::Meta.KeymapDescription}.
 *
 * Shell 50 builds one with {@code new_from_rules}, reads
 * {@code is_locked} and {@code direct_equal} on the compositor's
 * current description, and applies one with
 * {@code Backend.set_keymap_async}. The boxed value stays here.
 * The client holds a lease. The 16 build does not compile this file.
 *
 * == Example ==
 *
 * {{{
 * Gsr.Server.Meta.Keymap.rpc_register();
 * }}}
 */
namespace Gsr.Server.Meta
{
	public class Keymap : GLib.Object
	{
		/**
		 * Stock description this lease holds.
		 *
		 * {@code reset-keymap-description} reads it so mutter receives
		 * the boxed value the shell returned.
		 */
		public global::Meta.KeymapDescription? desc;

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-Mutter-Keymap", typeof(Keymap),
				"new_from_rules", "ssssasas",
				"is_locked", "",
				"direct_equal", "t",
				null
			);
			OLLMrpc.Request.add_class(
				"Gsr-Mutter-Backend", typeof(Keymap),
				"get_keymap_description", "",
				"set_keymap", "tu",
				null
			);
			var handler = new Keymap();
			OLLMrpc.Request.register_live("Gsr-Mutter-Keymap", handler);
			OLLMrpc.Request.register_live("Gsr-Mutter-Backend", handler);
		}

		/**
		 * ''Gsr-Mutter-Keymap.new_from_rules'' — stock
		 * {@code meta_keymap_description_new_from_rules}.
		 *
		 * @param request inbound RPC
		 * @param model xkb model
		 * @param layout comma-joined layouts
		 * @param variant comma-joined variants
		 * @param options xkb options string
		 * @param display_names one display name per layout
		 * @param short_names one short name per layout
		 */
		public void new_from_rules(
			OLLMrpc.Request request,
			string model,
			string layout,
			string variant,
			string options,
			string[] display_names,
			string[] short_names
		) {
			var row = new Keymap();
			row.desc = new global::Meta.KeymapDescription.from_rules(
				model, layout, variant, options, display_names, short_names);
			var handle = (uint64) request.connection.export(row);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}

		/**
		 * ''Gsr-Mutter-Keymap.is_locked'' — stock
		 * {@code meta_keymap_description_is_locked} on the lease.
		 *
		 * @param request inbound RPC; lease is the description
		 */
		public void is_locked(OLLMrpc.Request request)
		{
			var row = request.connection.leases.get((int) request.lease_id)
				as Keymap;
			if (row == null || row.desc == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", row.desc.is_locked()),
			});
		}

		/**
		 * ''Gsr-Mutter-Keymap.direct_equal'' — stock
		 * {@code meta_keymap_description_direct_equal}.
		 *
		 * @param request inbound RPC; lease is the receiver
		 * @param other_lid lease of the other description
		 */
		public void direct_equal(OLLMrpc.Request request, uint64 other_lid)
		{
			var row = request.connection.leases.get((int) request.lease_id)
				as Keymap;
			var other = request.connection.leases.get((int) other_lid) as Keymap;
			if (row == null || row.desc == null
				|| other == null || other.desc == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", row.desc.direct_equal(other.desc)),
			});
		}

		/**
		 * ''Gsr-Mutter-Backend.get_keymap_description'' — stock
		 * {@code meta_backend_get_keymap_description}.
		 *
		 * @param request inbound RPC; lease is the backend
		 */
		public void get_keymap_description(OLLMrpc.Request request)
		{
			var backend = request.connection.leases.get((int) request.lease_id)
				as global::Meta.Backend;
			if (backend == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var borrowed = backend.get_keymap_description();
			if (borrowed == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var row = new Keymap();
			row.desc = borrowed.ref();
			var handle = (uint64) request.connection.export(row);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}

		/**
		 * ''Gsr-Mutter-Backend.set_keymap'' — stock
		 * {@code meta_backend_set_keymap_async}. The reply is sent
		 * from the finish callback. The call site's cancellable is null.
		 *
		 * @param request inbound RPC; lease is the backend
		 * @param desc_lid lease of the description to apply
		 * @param layout_index group to select
		 */
		public void set_keymap(
			OLLMrpc.Request request,
			uint64 desc_lid,
			uint32 layout_index
		) {
			var backend = request.connection.leases.get((int) request.lease_id)
				as global::Meta.Backend;
			var row = request.connection.leases.get((int) desc_lid) as Keymap;
			if (backend == null || row == null || row.desc == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			backend.set_keymap_async.begin(
				row.desc, layout_index, null, (obj, res) => {
				try {
					backend.set_keymap_async.end(res);
				} catch (GLib.Error e) {
					request.connection.reply_error(request,
						(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e);
					return;
				}
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
			});
		}
	}
}
