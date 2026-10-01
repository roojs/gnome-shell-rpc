namespace Gsr
{
	[CCode (cname = "gsr_client_clutter_batch_flush_prop")]
	private extern void flush_prop(GLib.Object? instance) throws GLib.Error;

	/**
	 * Sync RPC call with positional {@link GLib.Value}s and optional instance.
	 *
	 * An open {@link Clutter.Actor.prop_batch} with nothing in it is
	 * closed. A non-empty map is sent as
	 * ''Gsr-Clutter-Actor.add_properties'' and closed. Entries are added
	 * only by {@link Client.Clutter.Batch.call_value} while the batch is open, so
	 * the flush looks at the map size.
	 *
	 * @param method wire method (e.g. ''Meta-Window.minimize'')
	 * @param instance leased stub; {@link OLLMrpc.Live.Interface.rpc_lid}
	 *     → {@link OLLMrpc.Request.lease_id}
	 * @param args GIR-order IN / INOUT args from {@link OLLMrpc.args}
	 * @param buffer optional client→server {@link OLLMrpc.Live.Buffer}
	 *     (memfd / SCM_RIGHTS); not pixel ''ay'' on the bin
	 * @return the peer response
	 */
	public OLLMrpc.Response call_value(
		string method,
		GLib.Object? instance = null,
		Gee.ArrayList<GLib.Value?>? args = null,
		OLLMrpc.Live.Buffer? buffer = null
	) throws GLib.Error {
		flush_prop(instance);
		uint64 lease_id = 0;
		if (instance != null) {
			lease_id = Gsr.Client.Rpc.Runtime.lease_id_of(instance, method);
		}
		var req = new OLLMrpc.Request() {
			method = method,
			lease_id = lease_id,
			buffer = buffer,
		};
		if (args == null) {
			return Gsr.Client.Rpc.Runtime.do_call(req);
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
			var lease = Gsr.Client.Rpc.Runtime.lease_id_of(obj, method);
			var wire = GLib.Value(GLib.Type.UINT64);
			wire.set_uint64(lease);
			req.args.add(wire);
		}
		return Gsr.Client.Rpc.Runtime.do_call(req);
	}
}
