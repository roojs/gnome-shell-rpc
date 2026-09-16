/**
 * Helper-Actor — GJS {@code St.Widget} subclass peer; name-keyed
 * {@link Actor.vfuncs}. Measure/allocate/event emit lives in
 * {@link LayoutHooks}.
 */
namespace GnomeShellRpc.Rpc.Helper
{
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
				"allocate_public", "ay",
				"base_preferred_width", "d",
				"base_preferred_height", "d",
				"pointer_click", "dd",
				"fire_button_press", "",
				"fire_key", "uu",
				null);
			OLLMrpc.Request.register_live("Helper-Actor", helper);
		}

		/**
		 * ''Helper-Actor.add_hook'' — bind one named vfunc hook on the lease.
		 */
		public void add_hook(OLLMrpc.Request request,string vfunc_name, uint64 callback_id)
		{
			var peer = request.connection.leases.get((int) request.lease_id) as Actor;
			if (peer == null
					|| !request.connection.callbacks.has_key((int) callback_id)) {
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

		[CCode (cname = "clutter_actor_allocate")]
		static extern void clutter_actor_allocate_public(
			Clutter.Actor actor,
			Clutter.ActorBox box
		);

		/**
		 * ''Helper-Actor.allocate_public'' — C {@code clutter_actor_allocate}
		 * (adjust_allocation then Class->allocate). GI
		 * {@code Clutter-Actor.allocate} hits klass->allocate and skips
		 * that wrapper (workspace-dot-align-smoke C).
		 */
		public void allocate_public(OLLMrpc.Request request, GLib.Bytes box_bytes)
		{
			var peer = request.connection.leases.get((int) request.lease_id) as Actor;
			if (peer == null || box_bytes.length < sizeof(Clutter.ActorBox)) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			Clutter.ActorBox box = *((Clutter.ActorBox*) box_bytes.get_data());
			clutter_actor_allocate_public(peer, box);
			request.reply(new OLLMrpc.Response());
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
				/* Parent ClutterActorClass.event is NULL on St.Widget —
				 * Vala base.event would call through 0 (motion SIGSEGV). */
				return false;
			}
			if (LayoutHooks.measure_event(hook, this, clutter_event)) {
				return true;
			}
			return false;
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
			hook.emit(OLLMrpc.args("tiddu",
				hook.connection.export(actor),
				(int) Clutter.EventType.BUTTON_PRESS,
				(double) (ax + actor.get_width() / 2.0f),
				(double) (ay + actor.get_height() / 2.0f),
				(uint32) Clutter.Button.PRIMARY));
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		/**
		 * ''Helper-Actor.fire_key'' — nested B2 prove. Virtual keyboard
		 * keyval (+ optional Super/Ctrl/Alt/Shift) through mutter grabs.
		 * Not stock Shell; same seat pattern as {@link pointer_click}.
		 */
		public void fire_key(
			OLLMrpc.Request request,
			uint keyval,
			uint modifiers
		) {
			var backend = Clutter.get_default_backend();
			var seat = backend.get_default_seat();
			var virt = seat.create_virtual_device(
				Clutter.InputDeviceType.KEYBOARD_DEVICE);
			if (virt == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR);
				return;
			}
			var mods = (Clutter.ModifierType) modifiers;
			if ((mods & Clutter.ModifierType.SUPER_MASK) != 0) {
				virt.notify_keyval(0, Clutter.Key.Super_L,
					Clutter.KeyState.PRESSED);
			}
			if ((mods & Clutter.ModifierType.CONTROL_MASK) != 0) {
				virt.notify_keyval(0, Clutter.Key.Control_L,
					Clutter.KeyState.PRESSED);
			}
			if ((mods & Clutter.ModifierType.MOD1_MASK) != 0) {
				virt.notify_keyval(0, Clutter.Key.Alt_L,
					Clutter.KeyState.PRESSED);
			}
			if ((mods & Clutter.ModifierType.SHIFT_MASK) != 0) {
				virt.notify_keyval(0, Clutter.Key.Shift_L,
					Clutter.KeyState.PRESSED);
			}
			virt.notify_keyval(0, keyval, Clutter.KeyState.PRESSED);
			virt.notify_keyval(0, keyval, Clutter.KeyState.RELEASED);
			if ((mods & Clutter.ModifierType.SHIFT_MASK) != 0) {
				virt.notify_keyval(0, Clutter.Key.Shift_L,
					Clutter.KeyState.RELEASED);
			}
			if ((mods & Clutter.ModifierType.MOD1_MASK) != 0) {
				virt.notify_keyval(0, Clutter.Key.Alt_L,
					Clutter.KeyState.RELEASED);
			}
			if ((mods & Clutter.ModifierType.CONTROL_MASK) != 0) {
				virt.notify_keyval(0, Clutter.Key.Control_L,
					Clutter.KeyState.RELEASED);
			}
			if ((mods & Clutter.ModifierType.SUPER_MASK) != 0) {
				virt.notify_keyval(0, Clutter.Key.Super_L,
					Clutter.KeyState.RELEASED);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
