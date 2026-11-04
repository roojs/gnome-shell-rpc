namespace ClutterGestureInvokerGate
{
	public class Gesture : GLib.Object
	{
		[CCode (cname = "clutter_gesture_get_point_event")]
		public int get_point_event(int point_index)
		{
			return point_index;
		}
	}
}
