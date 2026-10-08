/* Minimal St.Widget for mutter-rpc Helper layout relay (no full St.vapi). */
[CCode (cprefix = "St", lower_case_cprefix = "st_")]
namespace St {
	[CCode (cname = "StWidget", type_id = "st_widget_get_type ()", cheader_filename = "st-widget-peer.h")]
	public class Widget : Clutter.Actor {
		[CCode (has_construct_function = false)]
		protected Widget ();

		/* Class slot @ StWidgetClass.style_changed (st-widget-peer.h). */
		public virtual void style_changed ();
		public unowned string? get_style_class_name ();
	}

	[CCode (cname = "StDrawingArea", type_id = "st_drawing_area_get_type ()", cheader_filename = "st-widget-peer.h")]
	public class DrawingArea : Widget {
		[CCode (has_construct_function = false)]
		protected DrawingArea ();

		public unowned Cairo.Context get_context ();
		public signal void repaint ();
	}
}
