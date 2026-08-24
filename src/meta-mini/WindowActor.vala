// FIXME: 0.5.3 POC — leased Clutter show/hide; replace with generator emit.
namespace Meta
{
	/** Leased window actor — forwards selected Clutter APIs over RPC. */
	public class WindowActor : Clutter.Actor
	{
		public override void show()
		{
			var lease = this.get_data<string>("gsr-lease-id");
			if (lease != null && lease.length > 0) {
				GnomeShellRpc.GiStub.Runtime.call_values("Clutter-Actor.show", this);
				return;
			}
			base.show();
		}

		public override void hide()
		{
			var lease = this.get_data<string>("gsr-lease-id");
			if (lease != null && lease.length > 0) {
				GnomeShellRpc.GiStub.Runtime.call_values("Clutter-Actor.hide", this);
				return;
			}
			base.hide();
		}
	}
}
