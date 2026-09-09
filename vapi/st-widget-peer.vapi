/* Minimal St.Widget for mutter-rpc Helper layout relay (no full St.vapi). */
[CCode (cprefix = "St", lower_case_cprefix = "st_")]
namespace St {
	[CCode (cname = "StWidget", type_id = "st_widget_get_type ()", cheader_filename = "st-widget-peer.h")]
	public class Widget : Clutter.Actor {
		[CCode (has_construct_function = false)]
		protected Widget ();
	}
}
