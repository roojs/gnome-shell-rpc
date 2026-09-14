/**
 * Layout relay for GJS {@code St.Widget} subclasses — name-keyed
 * {@link Actor.vfuncs}; emit helpers take the hook.
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
			return true;
		}

		/**
		 * Emit allocate hook. {@code true} = JS applied;
		 * {@code false} = chain — caller runs {@code base.allocate}.
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
			actor.set_allocation(box);
			return true;
		}

		/**
		 * Emit event hook. {@code true} = JS handled (EVENT_STOP);
		 * {@code false} = fall through — caller runs {@code base.event}.
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
			hook.emit(OLLMrpc.args("tiidu",
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
	}

	public class Actor : global::St.Widget
	{
		public Gee.HashMap<string, OLLMrpc.Live.Hook> vfuncs
			= new Gee.HashMap<string, OLLMrpc.Live.Hook>();
		public string? client_type_name;

		public static void rpc_register()
		{
			var helper = new Actor();
			OLLMrpc.Request.add_class(
				"Helper-Actor", typeof(Actor),
				"create", "s",
				"add_hook", "st",
				"base_preferred_width", "d",
				"base_preferred_height", "d",
				"pointer_click", "dd",
				"fire_button_press", "",
				null);
			OLLMrpc.Request.register_live("Helper-Actor", helper);
		}

		/**
		 * ''Helper-Actor.add_hook'' — bind one named vfunc hook on the lease.
		 */
		public void add_hook(
			OLLMrpc.Request request,
			string vfunc_name,
			uint64 callback_id
		) {
			var peer = (Actor) request.connection.leases.get(
				(int) request.lease_id);
			if (peer == null
					|| !request.connection.callbacks.has_key(
						(int) callback_id)) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			peer.vfuncs.set(vfunc_name,
				request.connection.callbacks.get((int) callback_id));
			request.reply(new OLLMrpc.Response());
		}

		/**
		 * ''Helper-Actor.create'' — type_name only; hooks via add_hook.
		 */
		public void create(OLLMrpc.Request request, string type_name)
		{
			var created = new Actor();
			created.client_type_name = type_name;
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t",
					(uint64) request.connection.export(created)),
			});
		}

		public override void get_preferred_width(
			float for_height,
			out float min_width_p,
			out float natural_width_p
		) {
			var hook = this.vfuncs.get("get_preferred_width");
			if (hook == null) {
				base.get_preferred_width(
					for_height, out min_width_p, out natural_width_p);
				return;
			}
			if (LayoutHooks.measure_width(
					hook, this, for_height,
					out min_width_p, out natural_width_p)) {
				return;
			}
			var saved = this.vfuncs;
			this.vfuncs = new Gee.HashMap<string, OLLMrpc.Live.Hook>();
			base.get_preferred_width(
				for_height, out min_width_p, out natural_width_p);
			this.vfuncs = saved;
		}

		public override void get_preferred_height(
			float for_width,
			out float min_height_p,
			out float natural_height_p
		) {
			var hook = this.vfuncs.get("get_preferred_height");
			if (hook == null) {
				base.get_preferred_height(
					for_width, out min_height_p, out natural_height_p);
				return;
			}
			if (LayoutHooks.measure_height(
					hook, this, for_width,
					out min_height_p, out natural_height_p)) {
				return;
			}
			var saved = this.vfuncs;
			this.vfuncs = new Gee.HashMap<string, OLLMrpc.Live.Hook>();
			base.get_preferred_height(
				for_width, out min_height_p, out natural_height_p);
			this.vfuncs = saved;
		}

		public override void allocate(Clutter.ActorBox box)
		{
			var hook = this.vfuncs.get("allocate");
			if (hook == null) {
				base.allocate(box);
				return;
			}
			if (LayoutHooks.measure_allocate(hook, this, box)) {
				return;
			}
			var saved = this.vfuncs;
			this.vfuncs = new Gee.HashMap<string, OLLMrpc.Live.Hook>();
			base.allocate(box);
			this.vfuncs = saved;
		}

		/**
		 * ''Helper-Actor.base_preferred_width'' — St measure with hooks popped.
		 */
		public void base_preferred_width(
			OLLMrpc.Request request,
			double for_height
		) {
			var saved = this.vfuncs;
			this.vfuncs = new Gee.HashMap<string, OLLMrpc.Live.Hook>();
			float min_width_p = 0.0f, natural_width_p = 0.0f;
			if (this.get_stage() != null) {
				base.get_preferred_width(
					(float) for_height, out min_width_p, out natural_width_p);
			}
			this.vfuncs = saved;
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("dd",
					(double) min_width_p, (double) natural_width_p),
			});
		}

		/**
		 * ''Helper-Actor.base_preferred_height'' — see base_preferred_width.
		 */
		public void base_preferred_height(
			OLLMrpc.Request request,
			double for_width
		) {
			var saved = this.vfuncs;
			this.vfuncs = new Gee.HashMap<string, OLLMrpc.Live.Hook>();
			float min_height_p = 0.0f, natural_height_p = 0.0f;
			if (this.get_stage() != null) {
				base.get_preferred_height(
					(float) for_width, out min_height_p, out natural_height_p);
			}
			this.vfuncs = saved;
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("dd",
					(double) min_height_p, (double) natural_height_p),
			});
		}

		public override bool event(Clutter.Event clutter_event)
		{
			var hook = this.vfuncs.get("event");
			if (hook == null) {
				return base.event(clutter_event);
			}
			if (LayoutHooks.measure_event(hook, this, clutter_event)) {
				return true;
			}
			return base.event(clutter_event);
		}

		/**
		 * ''Helper-Actor.pointer_click'' — stage coords; virtual pointer
		 * motion + primary press/release (B3 hit-test prove).
		 */
		public void pointer_click(OLLMrpc.Request request, double x, double y)
		{
			var backend = Clutter.get_default_backend();
			var seat = backend.get_default_seat();
			var virt = seat.create_virtual_device(
				Clutter.InputDeviceType.POINTER_DEVICE);
			if (virt == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR);
				return;
			}
			virt.notify_absolute_motion(0, x, y);
			virt.notify_button(1, Clutter.Button.PRIMARY,
				Clutter.ButtonState.PRESSED);
			virt.notify_button(2, Clutter.Button.PRIMARY,
				Clutter.ButtonState.RELEASED);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		/**
		 * ''Helper-Actor.fire_button_press'' — fire the leased peer's
		 * {@code event} Live.Hook (same emit as {@link event} / 
		 * {@link LayoutHooks.measure_event}). Seat/pick path is
		 * {@link pointer_click}.
		 */
		public void fire_button_press(OLLMrpc.Request request)
		{
			var actor = (Actor) request.connection.leases.get(
				(int) request.lease_id);
			if (actor == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var hook = actor.vfuncs.get("event");
			if (hook == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			float ax = 0.0f, ay = 0.0f;
			actor.get_transformed_position(out ax, out ay);
			hook.emit(OLLMrpc.args("tiidu",
				hook.connection.export(actor),
				(int) Clutter.EventType.BUTTON_PRESS,
				(double) (ax + actor.get_width() / 2.0f),
				(double) (ay + actor.get_height() / 2.0f),
				(uint32) Clutter.Button.PRIMARY));
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
