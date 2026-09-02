/**
 * Owned {@code Shell.WorkspaceBackground} — stock shell-workspace-background
 * (0.7.7 T-039). GJS owns drawing; we hold construct props used at allocate.
 */
namespace Shell
{
	public class WorkspaceBackground : St.Widget
	{
		public int monitor_index { get; construct set; default = 0; }
		public double state_adjustment_value { get; set; default = 0; }

		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			var t = this.get_type();
			if (t != typeof(WorkspaceBackground) && !t.name().has_prefix("Gjs_")) {
				return;
			}
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"St-Widget.new", null);
			var stub = response.retval.get_object() as OLLMrpc.Live.Handle;
			this.rpc_lid = stub.rpc_lid;
		}
	}
}
