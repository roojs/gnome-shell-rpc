/**
 * Server pack of a {@link global::Clutter.Event}.
 *
 * One {@link Gsr.Shared.ClutterEventState}. Only the fields that
 * event type stores are set. Derived getters are not stored:
 * {@code get_distance}, {@code get_angle}, {@code get_position},
 * {@code has_shift_modifier}, {@code has_control_modifier},
 * {@code is_pointer_emulated}.
 */
namespace Gsr.Server.Clutter
{
	public class ClutterEventOverride : OLLMrpc.Bin.TypeOverride
	{
		[CCode (cname = "clutter_event_get_axes", array_length_pos = 1.1, array_length_type = "guint")]
		private static extern unowned double[] clutter_event_get_axes(
			[CCode (type = "const ClutterEvent*")] global::Clutter.Event event);

		[CCode (cname = "clutter_event_get_relative_motion")]
		private static extern bool clutter_event_get_relative_motion(
			[CCode (type = "const ClutterEvent*")] global::Clutter.Event event,
			out double dx,
			out double dy,
			out double dx_unaccel,
			out double dy_unaccel,
			out double dx_constrained,
			out double dy_constrained
		);

		[CCode (cname = "clutter_event_get_im_location")]
		private static extern bool clutter_event_get_im_location(
			[CCode (type = "const ClutterEvent*")] global::Clutter.Event event,
			out int32 offset,
			out int32 anchor
		);

		/**
		 * GType this override replaces on the wire.
		 */
		public override GLib.Type override_type {
			get {
				return typeof(global::Clutter.Event);
			}
		}

		/**
		 * One {@link Gsr.Shared.ClutterEventState}, fields for this event type.
		 *
		 * @param src the signal argument
		 * @return that object
		 */
		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			var ev = (global::Clutter.Event) src.get_boxed();
			var row = new Gsr.Shared.ClutterEventState();
			var et = ev.get_type();
			row.event_type = (int) et;
			row.flags = (uint) ev.get_flags();
			row.time = ev.get_time();
			row.time_us = ev.get_time_us();
			unowned global::Clutter.InputDevice? device = null;
			var x = 0f;
			var y = 0f;
			switch (et) {
				case global::Clutter.EventType.KEY_PRESS:
				case global::Clutter.EventType.KEY_RELEASE:
					device = ev.get_source_device();
					row.state = (uint) ev.get_state();
					row.key_symbol = ev.get_key_symbol();
					row.key_code = ev.get_key_code();
					row.key_unicode = ev.get_key_unicode();
					global::Clutter.ModifierType pressed = 0, latched = 0, locked = 0;
					ev.get_key_state(out pressed, out latched, out locked);
					row.key_pressed = (uint) pressed;
					row.key_latched = (uint) latched;
					row.key_locked = (uint) locked;
					row.event_code = ev.get_event_code();
					break;
				case global::Clutter.EventType.BUTTON_PRESS:
				case global::Clutter.EventType.BUTTON_RELEASE:
					device = ev.get_source_device();
					ev.get_coords(out x, out y);
					row.x = x;
					row.y = y;
					row.state = (uint) ev.get_state();
					row.button = ev.get_button();
					row.event_code = ev.get_event_code();
					row.tool_object = ev.get_device_tool();
					unowned double[] button_axes = clutter_event_get_axes(ev);
					if (button_axes != null && button_axes.length > 0) {
						var parts = new string[button_axes.length];
						for (var i = 0; i < button_axes.length; i++) {
							parts[i] = button_axes[i].to_string();
						}
						row.axes = string.joinv(",", parts);
					}
					break;
				case global::Clutter.EventType.MOTION:
					device = ev.get_source_device();
					ev.get_coords(out x, out y);
					row.x = x;
					row.y = y;
					row.state = (uint) ev.get_state();
					row.tool_object = ev.get_device_tool();
					var rdx = 0.0;
					var rdy = 0.0;
					var rudx = 0.0;
					var rudy = 0.0;
					var rcdx = 0.0;
					var rcdy = 0.0;
					row.rel_ok = clutter_event_get_relative_motion(
						ev, out rdx, out rdy, out rudx, out rudy, out rcdx, out rcdy);
					row.rel_dx = rdx;
					row.rel_dy = rdy;
					row.rel_udx = rudx;
					row.rel_udy = rudy;
					row.rel_cdx = rcdx;
					row.rel_cdy = rcdy;
					unowned double[] motion_axes = clutter_event_get_axes(ev);
					if (motion_axes != null && motion_axes.length > 0) {
						var parts = new string[motion_axes.length];
						for (var i = 0; i < motion_axes.length; i++) {
							parts[i] = motion_axes[i].to_string();
						}
						row.axes = string.joinv(",", parts);
					}
					break;
				case global::Clutter.EventType.ENTER:
				case global::Clutter.EventType.LEAVE:
					device = ev.get_source_device();
					ev.get_coords(out x, out y);
					row.x = x;
					row.y = y;
					row.source_object = ev.get_source();
					row.related_object = ev.get_related();
					var crossing_sequence = ev.get_event_sequence();
					if (crossing_sequence != null) {
						row.sequence_slot = crossing_sequence.get_slot();
					}
					break;
				case global::Clutter.EventType.SCROLL:
					device = ev.get_source_device();
					ev.get_coords(out x, out y);
					row.x = x;
					row.y = y;
					row.state = (uint) ev.get_state();
					row.tool_object = ev.get_device_tool();
					var sdx = 0.0;
					var sdy = 0.0;
					ev.get_scroll_delta(out sdx, out sdy);
					row.scroll_direction = (uint) ev.get_scroll_direction();
					row.scroll_dx = sdx;
					row.scroll_dy = sdy;
					row.scroll_source = (uint) ev.get_scroll_source();
					row.scroll_finish = (uint) ev.get_scroll_finish_flags();
					break;
				case global::Clutter.EventType.TOUCH_BEGIN:
				case global::Clutter.EventType.TOUCH_UPDATE:
				case global::Clutter.EventType.TOUCH_END:
					device = ev.get_source_device();
					ev.get_coords(out x, out y);
					row.x = x;
					row.y = y;
					row.state = (uint) ev.get_state();
					var touch_sequence = ev.get_event_sequence();
					if (touch_sequence != null) {
						row.sequence_slot = touch_sequence.get_slot();
					}
					break;
				case global::Clutter.EventType.TOUCH_CANCEL:
					device = ev.get_source_device();
					var cancel_sequence = ev.get_event_sequence();
					if (cancel_sequence != null) {
						row.sequence_slot = cancel_sequence.get_slot();
					}
					break;
				case global::Clutter.EventType.TOUCHPAD_PINCH:
				case global::Clutter.EventType.TOUCHPAD_SWIPE:
					device = ev.get_source_device();
					ev.get_coords(out x, out y);
					row.x = x;
					row.y = y;
					row.gesture_phase = (uint) ev.get_gesture_phase();
					row.touchpad_fingers = ev.get_touchpad_gesture_finger_count();
					var gdx = 0.0;
					var gdy = 0.0;
					var gudx = 0.0;
					var gudy = 0.0;
					ev.get_gesture_motion_delta(out gdx, out gdy);
					ev.get_gesture_motion_delta_unaccelerated(out gudx, out gudy);
					row.gesture_dx = gdx;
					row.gesture_dy = gdy;
					row.gesture_udx = gudx;
					row.gesture_udy = gudy;
					if (et == global::Clutter.EventType.TOUCHPAD_PINCH) {
						row.pinch_angle = ev.get_gesture_pinch_angle_delta();
						row.pinch_scale = ev.get_gesture_pinch_scale();
					}
					break;
				case global::Clutter.EventType.TOUCHPAD_HOLD:
					device = ev.get_source_device();
					ev.get_coords(out x, out y);
					row.x = x;
					row.y = y;
					row.gesture_phase = (uint) ev.get_gesture_phase();
					row.touchpad_fingers = ev.get_touchpad_gesture_finger_count();
					break;
				case global::Clutter.EventType.PROXIMITY_IN:
				case global::Clutter.EventType.PROXIMITY_OUT:
					device = ev.get_source_device();
					row.tool_object = ev.get_device_tool();
					break;
				case global::Clutter.EventType.PAD_BUTTON_PRESS:
				case global::Clutter.EventType.PAD_BUTTON_RELEASE:
					device = ev.get_source_device();
					row.button = ev.get_button();
					row.mode_group = ev.get_mode_group();
					uint button_pad_number = 0, button_pad_mode = 0;
					global::Clutter.InputDevicePadSource button_pad_source = 0;
					var button_pad_value = 0.0;
					row.pad_ok = ev.get_pad_details(
						out button_pad_number, out button_pad_mode,
						out button_pad_source, out button_pad_value);
					row.pad_number = button_pad_number;
					row.pad_mode = button_pad_mode;
					row.pad_source = (uint) button_pad_source;
					row.pad_value = button_pad_value;
					break;
				case global::Clutter.EventType.PAD_STRIP:
				case global::Clutter.EventType.PAD_RING:
					device = ev.get_source_device();
					row.mode_group = ev.get_mode_group();
					uint pad_number = 0, pad_mode = 0;
					global::Clutter.InputDevicePadSource pad_source = 0;
					var pad_value = 0.0;
					row.pad_ok = ev.get_pad_details(
						out pad_number, out pad_mode, out pad_source, out pad_value);
					row.pad_number = pad_number;
					row.pad_mode = pad_mode;
					row.pad_source = (uint) pad_source;
					row.pad_value = pad_value;
					break;
				case global::Clutter.EventType.DEVICE_ADDED:
				case global::Clutter.EventType.DEVICE_REMOVED:
					device = ev.get_source_device();
					break;
				case global::Clutter.EventType.IM_COMMIT:
				case global::Clutter.EventType.IM_DELETE:
				case global::Clutter.EventType.IM_PREEDIT:
					var text = ev.get_im_text();
					row.im_text = text != null ? text : "";
					var im_offset = (int32) 0;
					var im_anchor = (int32) 0;
					row.im_loc = clutter_event_get_im_location(
						ev, out im_offset, out im_anchor);
					row.im_offset = im_offset;
					row.im_anchor = im_anchor;
					row.im_delete = ev.get_im_delete_length();
					row.im_preedit = (uint) ev.get_im_preedit_reset_mode();
					break;
				default:
					break;
			}
			if (device != null) {
				row.device_type = (int) device.get_device_type();
			}
			var fields = new Gee.ArrayList<GLib.Value?>();
			fields.add(OLLMrpc.val("o", row));
			return fields;
		}

		/**
		 * Unused on the compositor. The client rebuilds the event.
		 *
		 * @param fields the notification arguments
		 * @param index first field for this argument
		 * @param consumed how many fields this argument used
		 * @return an empty event value
		 */
		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 1;
			return GLib.Value(typeof(global::Clutter.Event));
		}
	}
}
