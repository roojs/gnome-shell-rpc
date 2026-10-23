/**
 * Owned {@code Shell.SquareBin} — stock shell-square-bin (0.7.7 T-033).
 *
 * Extends {@link St.Bin}. Preferred width follows preferred height.
 * {@code rpc_construct} leases {@code Gsr-St-SquareBin.new}.
 * A GJS subclass inherits this override.
 */
namespace Shell
{
	public class SquareBin : St.Bin
	{
		/**
		 * Square peer. {@code St-Bin.new} stays a plain bin.
		 * {@code Actor.construct} subscribes signals after this.
		 */
		public override void rpc_construct()
		{
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-St-SquareBin.new", null,
				OLLMrpc.args("t", (uint64) 0));
			var stub = response.retval.get_object() as OLLMrpc.Live.Interface;
			this.rpc_lid = stub.rpc_lid;
			Gsr.Client.Rpc.register_handle(this);
		}

		public override void get_preferred_width_vfunc(
			float for_height,
			out float min_width_p,
			out float natural_width_p
		) {
			/* Stock calls get_preferred_height. The public method bails
			 * with 0 while a preferred-size hook is active, which is
			 * this call. Ask the server bin for its height instead. */
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Clutter-Actor.base_preferred_height", this,
				OLLMrpc.args("d", -1.0));
			min_width_p = (float) response.args.get(0).get_double();
			natural_width_p = (float) response.args.get(1).get_double();
		}
	}
}
