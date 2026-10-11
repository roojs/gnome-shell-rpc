/**
 * Delivers {@link global::Meta.Window} Override RPC (plan 0.5.6 B3).
 *
 * Wire prefix ''Gsr-Mutter-Window''. Lease is the window.
 * {@link global::Meta.WindowForeachFunc} continue is the bool on
 * {@link OLLMrpc.Live.Hook.reply_args} after {@code RPC-Live-Callback.reply}.
 */
namespace Gsr.Server.Meta
{
	public class Window : GLib.Object
	{
		[CCode (cname = "meta_shaped_texture_get_texture",
			cheader_filename = "meta/meta-shaped-texture.h")]
		private static extern void* shaped_buffer (global::Meta.ShapedTexture stex);

		[CCode (cname = "meta_multi_texture_get_n_planes",
			cheader_filename = "meta/meta-multi-texture.h")]
		private static extern int texture_planes (void* multi);

		[CCode (cname = "meta_multi_texture_get_plane",
			cheader_filename = "meta/meta-multi-texture.h")]
		private static extern void* texture_plane (void* multi, int index);

		[CCode (cname = "gsr_texture_read",
			cheader_filename = "server/libmutter-16/texture-read.h")]
		private static extern int texture_read (void* texture, [CCode (array_length = false)] uint8[] data, uint rowstride);

		[CCode (cname = "gsr_texture_readable",
			cheader_filename = "server/libmutter-16/texture-read.h")]
		private static extern bool texture_readable (void* texture);

		[CCode (cname = "gsr_texture_width",
			cheader_filename = "server/libmutter-16/texture-read.h")]
		private static extern int texture_width (void* texture);

		[CCode (cname = "gsr_texture_height",
			cheader_filename = "server/libmutter-16/texture-read.h")]
		private static extern int texture_height (void* texture);

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-Mutter-Window", typeof(Window),
				"foreach_transient", "t",
				"foreach_ancestor", "t",
				"begin_grab_op", "uosiubff",
				"get_compositor_private", "",
				null
			);
			OLLMrpc.Request.register_live("Gsr-Mutter-Window", new Window());
		}

		/**
		 * ''Gsr-Mutter-Window.get_compositor_private'' — lease of the
		 * live {@link global::Meta.WindowActor}. Same object
		 * {@link Gsr.Server.Meta.Compositor.get_window_actors} exports.
		 */
		public void get_compositor_private(OLLMrpc.Request request)
		{
			var window = (global::Meta.Window) request.connection.leases.get(
				(int) request.lease_id);
			var priv = window.get_compositor_private()
				as global::Meta.WindowActor;
			uint64 lid = 0;
			if (priv != null) {
				lid = request.connection.export(priv);
				var parent = priv.get_parent();
				var child = priv.get_first_child();
				var stex = priv.get_texture();
				string image = "no-buffer";
				var multi = stex != null ? Window.shaped_buffer(stex) : null;
				if (multi != null) {
					int planes = Window.texture_planes(multi);
					var plane = planes > 0 ? Window.texture_plane(multi, 0) : null;
					if (plane == null) {
						image = "planes=%d".printf(planes);
					} else {
						int tex_w = Window.texture_width(plane);
						int tex_h = Window.texture_height(plane);
						bool readable = Window.texture_readable(plane);
						int bytes = 0;
						string ink = "unread";
						if (tex_w > 0 && tex_h > 0 && tex_w <= 4096 && tex_h <= 4096) {
							var data = new uint8[tex_w * tex_h * 4];
							bytes = Window.texture_read(plane, data, (uint) (tex_w * 4));
							ink = "blank";
							int limit = bytes < data.length ? bytes : data.length;
							for (int i = 0; i < limit; i++) {
								if (data[i] != 0) {
									ink = "pixels";
									break;
								}
							}
							if (bytes <= 0) {
								ink = "fail";
							}
						}
						image = "planes=%d readable=%s %dx%d bytes=%d %s".printf(
							planes, readable ? "yes" : "no", tex_w, tex_h, bytes, ink);
					}
				}
				GLib.debug("compositor-private visible=%s mapped=%s realized=%s parent-mapped=%s children=%d stex=%s buffer=%s image=%s child-opacity=%u child-visible=%s child=%.0fx%.0f",
					priv.visible ? "yes" : "no",
					priv.mapped ? "yes" : "no",
					priv.realized ? "yes" : "no",
					parent != null && parent.mapped ? "yes" : "no",
					(int) priv.get_n_children(),
					stex != null ? "yes" : "no",
					stex != null && Window.shaped_buffer(stex) != null ? "yes" : "no",
					image,
					child != null ? child.opacity : 0,
					child != null && child.visible ? "yes" : "no",
					child != null ? child.width : -1,
					child != null ? child.height : -1);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", lid),
			});
		}

		public void foreach_transient(
			OLLMrpc.Request request,
			uint64 callback_id
		) {
			var window = (global::Meta.Window) request.connection.leases.get(
				(int) request.lease_id);
			if (!request.connection.callbacks.has_key((int) callback_id)) {
				GLib.warning("unknown callback id");
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			var row = request.connection.callbacks.get((int) callback_id);
			window.foreach_transient((w) => {
				row.emit(OLLMrpc.args("t", row.connection.export(w)));
				if (row.reply_args.size < 1) {
					return false;
				}
				return row.reply_args.get(0).get_boolean();
			});
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		public void foreach_ancestor(
			OLLMrpc.Request request,
			uint64 callback_id
		) {
			var window = (global::Meta.Window) request.connection.leases.get(
				(int) request.lease_id);
			if (!request.connection.callbacks.has_key((int) callback_id)) {
				GLib.warning("unknown callback id");
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			var row = request.connection.callbacks.get((int) callback_id);
			window.foreach_ancestor((w) => {
				row.emit(OLLMrpc.args("t", row.connection.export(w)));
				if (row.reply_args.size < 1) {
					return false;
				}
				return row.reply_args.get(0).get_boolean();
			});
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		public void begin_grab_op(
			OLLMrpc.Request request,
			uint op,
			global::Clutter.InputDevice? device,
			string device_name,
			int sequence_slot,
			uint timestamp,
			bool has_pos,
			float pos_x,
			float pos_y
		) {
			var window = (global::Meta.Window) request.connection.leases.get(
				(int) request.lease_id);
			var resolved = Gsr.Server.Clutter.Devices.resolve(device, device_name);
			Graphene.Point? pos_hint = null;
			if (has_pos) {
				Graphene.Point pos = {};
				pos.x = pos_x;
				pos.y = pos_y;
				pos_hint = pos;
			}
			/* EventSequence is process-local; slot alone cannot rebuild it. */
			global::Clutter.EventSequence? sequence = null;
			if (sequence_slot >= 0) {
				GLib.debug(
					"begin_grab_op: sequence slot %d ignored (no cross-process sequence)",
					sequence_slot);
			}
			var ok = window.begin_grab_op((global::Meta.GrabOp) op, resolved, sequence,
				timestamp, pos_hint);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", ok),
			});
		}
	}
}
