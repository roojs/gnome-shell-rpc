/**
 * Owned {@code Shell.SquareBin} — stock shell-square-bin (0.7.7 T-033).
 *
 * Extends {@link St.Bin}; preferred width follows preferred height so the
 * actor stays square. Lease is {@code St-Bin.new} (same server type).
 */
namespace Shell
{
	public class SquareBin : St.Bin
	{
		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			var t = this.get_type();
			if (t != typeof(SquareBin) && !t.name().has_prefix("Gjs_")) {
				return;
			}
			var response = GnomeShellRpc.call_value(
				"St-Bin.new");
			var stub = response.retval.get_object() as OLLMrpc.Live.Interface;
			this.rpc_lid = stub.rpc_lid;
		}

		public override void get_preferred_width_vfunc(
			float for_height,
			out float min_width_p,
			out float natural_width_p
		) {
			/* Stock calls get_preferred_height. The public method bails
			 * with 0 while a preferred-size hook is active, which is
			 * this call. Ask the server bin for its height instead. */
			var response = GnomeShellRpc.call_value(
				"Helper-Actor.base_preferred_height", this,
				OLLMrpc.args("d", -1.0));
			min_width_p = (float) response.args.get(0).get_double();
			natural_width_p = (float) response.args.get(1).get_double();
		}
	}
}
