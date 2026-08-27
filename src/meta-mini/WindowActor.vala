// FIXME: 0.5.3 POC — leased Clutter relay; replace with generator emit.
namespace Meta
{
	/**
	 * Client handle for a compositor window actor.
	 *
	 * Stock {@code Meta.WindowActor} is a {@code Clutter.Actor}. Mutter-clutter
	 * has no public init in this process, so the stub is a {@link GLib.Object}
	 * and forwards selected Clutter methods over RPC.
	 */
	public class WindowActor : GLib.Object
	{
		private static bool registered = false;

		/**
		 * Wire type for leased actors.
		 */
		public static void rpc_register()
		{
			if (WindowActor.registered) {
				return;
			}
			WindowActor.registered = true;
			try {
				OLLMrpc.Bin.register("Meta-WindowActor", typeof(WindowActor));
			} catch (GLib.Error e) {
				GLib.error("%s", e.message);
			}
		}

		public void show()
		{
			GnomeShellRpc.GiStub.Runtime.call_values("Clutter-Actor.show", this);
		}

		public void hide()
		{
			GnomeShellRpc.GiStub.Runtime.call_values("Clutter-Actor.hide", this);
		}

		public bool visible {
			get {
				var response = GnomeShellRpc.GiStub.Runtime.call_values(
					"Clutter-Actor.is_visible", this);
				return response.args.get(0).get_boolean();
			}
		}

		public void set_position(float x, float y)
		{
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.set_position",
				this,
				OLLMrpc.args("ff", x, y));
		}

		public void set_size(float width, float height)
		{
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.set_size",
				this,
				OLLMrpc.args("ff", width, height));
		}

		public void get_position(out float x, out float y)
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.get_position", this);
			x = (float) response.args.get(0).get_float();
			y = (float) response.args.get(1).get_float();
		}
	}
}
