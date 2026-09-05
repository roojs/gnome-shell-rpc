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
				"St-Bin.new", null);
			var stub = response.retval.get_object() as OLLMrpc.Live.Handle;
			this.rpc_lid = stub.rpc_lid;
		}

		public override void get_preferred_width(
			float for_height,
			out float min_width_p,
			out float natural_width_p
		) {
			float min_height;
			float natural_height;
			this.get_preferred_height(-1f, out min_height, out natural_height);
			min_width_p = min_height;
			natural_width_p = natural_height;
		}
	}
}
