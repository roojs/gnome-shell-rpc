/**
 * Live.Hook emit helpers for {@link Actor} vfuncs.
 *
 * 🚫 Do not revive emit_guard / {@code suppress_emit} / measure-depth skips.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class LayoutHooks
	{
		/**
		 * Emit preferred-width hook. {@code true} = sizes in outs;
		 * {@code false} = error / empty — caller runs {@code base}.
		 */
		public static bool measure_width(
			OLLMrpc.Live.Hook hook,
			Actor actor,
			float for_height,
			out float min_width_p,
			out float natural_width_p
		) {
			hook.emit(OLLMrpc.args("td",
				hook.connection.export(actor),
				(double) for_height));
			var args = hook.reply_args;
			if ((args.size == 1 && args.get(0).holds(typeof(OLLMrpc.Error)))
					|| args.size < 2) {
				min_width_p = 0.0f;
				natural_width_p = 0.0f;
				return false;
			}
			min_width_p = (float) args.get(0).get_double();
			natural_width_p = (float) args.get(1).get_double();
			GLib.debug("preferred-width type=%s min=%g nat=%g",
				actor.client_type_name != null ? actor.client_type_name : "?",
				min_width_p, natural_width_p);
			return true;
		}

		/**
		 * Emit preferred-height hook. {@code true} = sizes;
		 * {@code false} = error / empty — caller runs {@code base}.
		 */
		public static bool measure_height(
			OLLMrpc.Live.Hook hook,
			Actor actor,
			float for_width,
			out float min_height_p,
			out float natural_height_p
		) {
			hook.emit(OLLMrpc.args("td",
				hook.connection.export(actor),
				(double) for_width));
			var args = hook.reply_args;
			if ((args.size == 1 && args.get(0).holds(typeof(OLLMrpc.Error)))
					|| args.size < 2) {
				min_height_p = 0.0f;
				natural_height_p = 0.0f;
				return false;
			}
			min_height_p = (float) args.get(0).get_double();
			natural_height_p = (float) args.get(1).get_double();
			GLib.debug("preferred-height type=%s min=%g nat=%g",
				actor.client_type_name != null ? actor.client_type_name : "?",
				min_height_p, natural_height_p);
			return true;
		}

		/**
		 * Emit allocate hook. {@code true} = JS applied;
		 * {@code false} = chain — caller runs {@code base.allocate}.
		 *
		 * Non-chain: GJS Class->allocate must {@code set_allocation} (Clutter
		 * contract). Do not re-apply the pre-hook box — that wiped
		 * BoxPointer._reposition (actor-allocate-box-smoke / chrome menus).
		 */
		public static bool measure_allocate(
			OLLMrpc.Live.Hook hook,
			Actor actor,
			Clutter.ActorBox box
		) {
			hook.emit(OLLMrpc.args("tdddd",
				hook.connection.export(actor),
				(double) box.x1, (double) box.y1,
				(double) box.x2, (double) box.y2));
			if (hook.reply_args.size < 1) {
				return false;
			}
			var chain = hook.reply_args.get(0).type() == GLib.Type.BOOLEAN
				&& hook.reply_args.get(0).get_boolean();
			if (chain) {
				return false;
			}
			return true;
		}

		/**
		 * Emit event hook. {@code true} = JS handled (EVENT_STOP);
		 * {@code false} = fall through — caller returns false (propagate).
		 * 🚫 Do not {@code base.event}: St.Widget parent class slot is NULL.
		 */
		public static bool measure_event(
			OLLMrpc.Live.Hook hook,
			Actor actor,
			Clutter.Event event
		) {
			float x = 0.0f, y = 0.0f;
			event.get_coords(out x, out y);
			var et = event.get_type();
			uint32 button = 0;
			if (et == Clutter.EventType.BUTTON_PRESS
					|| et == Clutter.EventType.BUTTON_RELEASE
					|| et == Clutter.EventType.PAD_BUTTON_PRESS
					|| et == Clutter.EventType.PAD_BUTTON_RELEASE) {
				button = event.get_button();
			}
			hook.emit(OLLMrpc.args("tiddu",
				hook.connection.export(actor),
				(int) et,
				(double) x, (double) y,
				button));
			if (hook.reply_args.size < 1) {
				return false;
			}
			return hook.reply_args.get(0).type() == GLib.Type.BOOLEAN
				&& hook.reply_args.get(0).get_boolean();
		}

		/**
		 * Emit style-changed hook (void). Client emits
		 * {@code St.Widget::style-changed} for GJS connect handlers.
		 */
		public static void measure_style_changed(OLLMrpc.Live.Hook hook, Actor actor) 
		{
			hook.emit(OLLMrpc.args("t",	hook.connection.export(actor)));
		}
	}
}
