namespace EdgeDragProgressGate
{
	public class Current : GLib.Object
	{
	}

	public class Fixed : GLib.Object
	{
		public signal void progress(float progress_px);
	}
}
