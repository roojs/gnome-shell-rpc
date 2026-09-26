/**
 * Stores one {@link GLib.SourceFunc} the way {@code Meta.Laters.add} does
 * and invokes it later. Used from GJS after the bound object is disposed.
 */
namespace LaterCallbackHold
{
	public class Holder : GLib.Object
	{
		private GLib.SourceFunc? func;

		public void store (owned GLib.SourceFunc func)
		{
			this.func = (owned) func;
		}

		public bool fire ()
		{
			if (this.func == null) {
				return false;
			}
			return this.func ();
		}
	}
}
