/**
 * Helper-Transition — typed from/to relay for stock set_to_value /
 * set_from_value (GValue not on the wire). See
 * docs/bugs/2026-09-16-transition-interval-gvalue-wire.md (1.0 D1.7).
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Transition : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class("Helper-Transition", typeof(Transition),
				"set_relay_value", "bsid", null);
			OLLMrpc.Request.register_live(
				"Helper-Transition", new Transition());
		}

		/**
		 * ''Helper-Transition.set_relay_value'' — {@code is_to} picks
		 * stock set_to_value vs set_from_value; {@code kind} picks the
		 * fundamental; int/double slots hold the widened payload.
		 */
		public void set_relay_value(
			OLLMrpc.Request request,
			bool is_to,
			string kind,
			int i,
			double d
		) {
			var peer = (Clutter.Transition) request.connection.leases.get(
				(int) request.lease_id);
			if (peer == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			GLib.Value v = {};
			switch (kind) {
				case "i":
					v = GLib.Value(typeof(int));
					v.set_int(i);
					break;
				case "u":
					v = GLib.Value(typeof(uint));
					v.set_uint((uint) i);
					break;
				case "b":
					v = GLib.Value(typeof(bool));
					v.set_boolean(i != 0);
					break;
				case "c":
					v = GLib.Value(typeof(char));
					v.set_schar((int8) i);
					break;
				case "y":
					v = GLib.Value(typeof(uchar));
					v.set_uchar((uint8) i);
					break;
				case "f":
					v = GLib.Value(typeof(float));
					v.set_float((float) d);
					break;
				case "d":
					v = GLib.Value(typeof(double));
					v.set_double(d);
					break;
				default:
					request.connection.reply_error(request,
						(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
					return;
			}
			if (is_to) {
				peer.set_to_value(v);
			} else {
				peer.set_from_value(v);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
