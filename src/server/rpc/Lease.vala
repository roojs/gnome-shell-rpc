namespace Gsr.Server.Rpc
{
	/**
	 * Something one client connection registered on the server.
	 * Dropping the lease undoes it.
	 *
	 * - {@link global::Meta.Display} + name: add_keybinding
	 * - null target + name: keybindings_set_custom_handler
	 * - any other object + hid: a signal handler
	 */
	public class Lease : GLib.Object
	{
		private GLib.WeakRef target;
		private bool has_target;
		private string name;
		private ulong hid;

		public Lease(GLib.Object? target, string name = "", ulong hid = 0)
		{
			this.target = GLib.WeakRef(target);
			this.has_target = target != null;
			this.name = name;
			this.hid = hid;
		}

		~Lease()
		{
			if (!this.has_target) {
				global::Meta.KeyBinding.set_custom_handler(this.name, null);
				return;
			}
			var live = this.target.get();
			if (live == null) {
				return;
			}
			if (live is global::Meta.Display) {
				((global::Meta.Display) live).remove_keybinding(this.name);
				return;
			}
			if (this.hid != 0) {
				GLib.SignalHandler.disconnect(live, this.hid);
			}
		}
	}
}
