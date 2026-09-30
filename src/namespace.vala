/**
 * Nested mutter compositor exposing desktop state over GObject RPC.
 *
 * {@link Plugin} is the in-process {@link Meta.Plugin}. The process starts
 * a {@link Meta.Context} the same way Gala does: the Vala binary links
 * libmutter and calls {@link Meta.Context.set_plugin_gtype}. Stock mutter
 * is not loaded with `--mutter-plugin` yet.
 *
 * {@link GnomeShellRpc.Ui} types are the remote representation of what the
 * user sees. {@link GnomeShellRpc.Rpc.Server} listens on a Unix socket.
 *
 * == Example ==
 *
 * {{{
 * dbus-run-session ./build/src/mutter-rpc --wayland --nested
 * }}}
 */
namespace GnomeShellRpc
{
#if GSR_GI_STUB
	/**
	 * Sync RPC call with positional {@link GLib.Value}s and optional instance.
	 *
	 * While {@link Clutter.Actor.prop_batch_open} is set, ''hide'',
	 * ''show'', or a one-argument setter whose value matches the
	 * property is stored and this returns an empty response. A
	 * setter whose value cannot be stored on that property, such as
	 * ''Helper-Icon.set_gicon'' (a string for a ''GIcon''), is sent
	 * as itself. The next other call sends
	 * ''Helper-Actor.add_properties'' and then runs itself.
	 *
	 * @param method wire method (e.g. ''Meta-Window.minimize'')
	 * @param instance leased stub; {@link OLLMrpc.Live.Interface.rpc_lid}
	 *     → {@link OLLMrpc.Request.lease_id}
	 * @param args GIR-order IN / INOUT args from {@link OLLMrpc.args}
	 * @param buffer optional client→server {@link OLLMrpc.Live.Buffer}
	 *     (memfd / SCM_RIGHTS); not pixel ''ay'' on the bin
	 * @return the peer response, or empty when the call was queued
	 */
	public OLLMrpc.Response call_value(
		string method,
		GLib.Object? instance = null,
		Gee.ArrayList<GLib.Value?>? args = null,
		OLLMrpc.Live.Buffer? buffer = null
	) throws GLib.Error {
		var actor = instance as Clutter.Actor;
		if (actor != null && actor.prop_batch_open
			&& (method.has_suffix(".hide") || method.has_suffix(".show"))) {
			var held = GLib.Value(typeof(bool));
			held.set_boolean(method.has_suffix(".show"));
			actor.prop_batch.set("visible", held);
			return new OLLMrpc.Response();
		}
		var name = "";
		if (actor != null && actor.prop_batch_open && args != null && args.size == 1) {
			var dot = method.last_index_of_char('.');
			var tail = dot < 0 ? method : method.substring(dot + 1);
			if (!tail.has_prefix("set_") || tail == "set_child") {
				tail = "";
			}
			if (tail != "") {
				name = tail.substring(4).replace("_", "-");
			}
		}
		if (name != "") {
			var pspec = actor.get_class().find_property(name);
			var held = args.get(0);
			if (pspec == null || held == null
					|| (!held.type().is_a(pspec.value_type)
						&& !GLib.Value.type_transformable(held.type(), pspec.value_type))) {
				name = "";
			}
		}
		if (name != "") {
			actor.prop_batch.set(name, args.get(0));
			return new OLLMrpc.Response();
		}
		if (actor != null && actor.prop_batch_open) {
			actor.prop_batch_open = false;
			if (actor.prop_batch.size > 0) {
				var send = new Gee.ArrayList<GLib.Value?>();
				foreach (var entry in actor.prop_batch.entries) {
					var key = GLib.Value(typeof(string));
					key.set_string(entry.key);
					send.add(key);
					send.add(entry.value);
				}
				actor.prop_batch.clear();
				GnomeShellRpc.call_value("Helper-Actor.add_properties", actor, send);
			}
		}
		uint64 lease_id = 0;
		if (instance != null) {
			lease_id = GiStub.Runtime.lease_id_of(instance, method);
		}
		var req = new OLLMrpc.Request() {
			method = method,
			lease_id = lease_id,
			buffer = buffer,
		};
		if (args == null) {
			return GiStub.Runtime.do_call(req);
		}
		foreach (var val in args) {
			if (!val.type().is_a(GLib.Type.OBJECT)) {
				req.args.add(val);
				continue;
			}
			var obj = val.get_object();
			if (obj == null) {
				var zero = GLib.Value(GLib.Type.UINT64);
				zero.set_uint64(0);
				req.args.add(zero);
				continue;
			}
			var lease = GiStub.Runtime.lease_id_of(obj, method);
			var wire = GLib.Value(GLib.Type.UINT64);
			wire.set_uint64(lease);
			req.args.add(wire);
		}
		return GiStub.Runtime.do_call(req);
	}
#endif
}
