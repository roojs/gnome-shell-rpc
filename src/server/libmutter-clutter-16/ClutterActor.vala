/**
 * Gsr-Clutter-Actor — GJS {@code global::St.Widget} subclass peer; slot-keyed
 * {@link Actor.vfuncs} ({@code vfunc_id}). Measure/allocate/event emit
 * lives in {@link LayoutHooks}.
 */
namespace Gsr.Server.Clutter
{
	public class Actor : global::St.Widget
	{
		public Gee.HashMap<int, OLLMrpc.Live.Hook> vfuncs {
			get; set; default = new Gee.HashMap<int, OLLMrpc.Live.Hook>();
		}
		/** Typelib name for each key in {@link vfuncs}. */
		public Gee.HashMap<int, string> method_names {
			get; set; default = new Gee.HashMap<int, string>();
		}
		static int style_changed_id;
		public string? client_type_name;

		public static void rpc_register()
		{
			var helper = new Actor();
			OLLMrpc.Request.add_class(
				"Gsr-Clutter-Actor", typeof(Actor),
				"create", "s",
				"add_hook", "it",
				"add_hooks", "Sv",
				"add_signals", "S",
				"add_properties", "",
				"allocate_public", "ay",
				"base_preferred_width", "d",
				"base_preferred_height", "d",
				"pointer_click", "dd",
				"fire_button_press", "",
				"fire_key", "uu",
				"deliver_event", "ibddduu",
				null);
			OLLMrpc.Request.register_live("Gsr-Clutter-Actor", helper);
			ActorVfuncIds.register_vfunc_ids();
			style_changed_id = OLLMrpc.Gi.vfunc_offset("St", "Widget", "style_changed");
		}

		/**
		 * ''Gsr-Clutter-Actor.add_hook'' — bind one vfunc hook on the lease.
		 */
		public void add_hook(OLLMrpc.Request request, int vfunc_id, uint64 hook_id)
		{
			if (!request.connection.callbacks.has_key((int) hook_id)) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var hook = request.connection.callbacks.get((int) hook_id);
			var peer = request.connection.leases.get((int) request.lease_id) as Actor;
			if (peer != null) {
				peer.vfuncs.set(vfunc_id, hook);
				request.reply(new OLLMrpc.Response());
				return;
			}
			var clutter_actor = request.connection.leases.get(
				(int) request.lease_id) as global::Clutter.Actor;
			if (clutter_actor == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			if (vfunc_id == ActorVfuncIds.event_id) {
				var leases = ((Gsr.Server.Rpc.Connection) request.connection).session_leases;
				leases.add(new Gsr.Server.Rpc.Lease(clutter_actor, "",
					clutter_actor.key_press_event.connect((a, ev) => {
						LayoutHooks.measure_event(hook, clutter_actor, ev);
						return false;
					})));
				leases.add(new Gsr.Server.Rpc.Lease(clutter_actor, "",
					clutter_actor.key_release_event.connect((a, ev) => {
						LayoutHooks.measure_event(hook, clutter_actor, ev);
						return false;
					})));
			}
			request.reply(new OLLMrpc.Response());
		}

		/**
		 * ''Gsr-Clutter-Actor.create'' — lease a helper for a client type.
		 *
		 * Hooks and signals are later calls. {@link add_hook} is
		 * still the call for one vfunc on an actor that already
		 * exists.
		 *
		 * @param request inbound RPC
		 * @param type_name client type, stored for later vfunc lookup
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

		/**
		 * ''Gsr-Clutter-Actor.add_hooks'' — store the construct vfuncs
		 * on the leased actor.
		 *
		 * One hook id is allocated per ''vfunc_ids'' entry and
		 * returned as ''at''. ''names'' is the typelib name for
		 * each slot, when that index is present.
		 *
		 * @param request inbound RPC
		 * @param names typelib name for each vfunc id
		 * @param vfunc_ids ''ai'' of vfunc slots
		 */
		public void add_hooks(
			OLLMrpc.Request request,
			string[] names,
			GLib.Variant vfunc_ids
		) {
			if (!request.connection.live_handles) {
				GLib.error("Actor.add_hooks requires live_handles");
			}
			var created = request.connection.leases.get((int) request.lease_id) as Actor;
			if (created == null) {
				request.connection.reply_error(request,	(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var n = (int) vfunc_ids.n_children();
			var ids = new GLib.VariantBuilder(new GLib.VariantType("at"));
			for (var i = 0; i < n; i++) {
				var id = request.connection.next_handle;
				request.connection.next_handle++;
				var hook = new OLLMrpc.Live.Hook() {
					connection = request.connection,
					id = id
				};
				request.connection.callbacks.set(id, hook);
				ids.add("t", (uint64) id);
				var vfunc_id = vfunc_ids.get_child_value(i).get_int32();
				created.vfuncs.set(vfunc_id, hook);
				if (i >= names.length) {
					continue;
				}
				created.method_names.set(vfunc_id, names[i]);
			}
			request.reply(new OLLMrpc.Response() {
				args = OLLMrpc.args("v", ids.end()),
			});
		}

		/**
		 * ''Gsr-Clutter-Actor.add_signals'' — subscribe each name on the lease.
		 *
		 * ''Subscription.connect'' writes no reply. This method
		 * replies once after the list. An empty name or a missing
		 * lease is ''-32602'' and no success reply.
		 *
		 * @param request inbound RPC
		 * @param names signal or ''notify::'' property
		 */
		public void add_signals(OLLMrpc.Request request, string[] names)
		{
			for (var i = 0; i < names.length; i++) {
				var subscription = new OLLMrpc.Live.Subscription() {
					connection = request.connection,
					method = names[i],
					id = (int) request.lease_id
				};
				if (!subscription.connect()) {
					request.connection.reply_error(request,
						(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
					return;
				}
			}
			request.reply(new OLLMrpc.Response());
		}

		/**
		 * ''Gsr-Clutter-Actor.add_properties'' — apply initial property
		 * pairs on the leased actor.
		 *
		 * Arguments are name, value, name, value. An object value
		 * is a lease id. An odd count, a missing lease, or an
		 * unknown property is ''-32602'' and no success reply.
		 *
		 * @param request inbound RPC; args are the pairs
		 */
		public void add_properties(OLLMrpc.Request request)
		{
			var obj = request.connection.leases.get((int) request.lease_id);
			if (obj == null || request.args.size % 2 != 0) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			for (var i = 0; i < request.args.size; i += 2) {
				var name = request.args.get(i).get_string();
				var value = request.args.get(i + 1);
				var pspec = obj.get_class().find_property(name);
				if (pspec == null) {
					request.connection.reply_error(request,
						(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
					return;
				}
				if (!pspec.value_type.is_a(GLib.Type.OBJECT)) {
					obj.set_property(name, value);
					continue;
				}
				var peer = request.connection.leases.get((int) value.get_uint64());
				var obj_value = GLib.Value(pspec.value_type);
				obj_value.set_object(peer);
				obj.set_property(name, obj_value);
			}
			request.reply(new OLLMrpc.Response());
		}

		public override void get_preferred_width(
			float for_height,
			out float min_width_p,
			out float natural_width_p
		) {
			var hook = this.vfuncs.get(ActorVfuncIds.get_preferred_width_id);
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
			this.vfuncs = new Gee.HashMap<int, OLLMrpc.Live.Hook>();
			base.get_preferred_width(
				for_height, out min_width_p, out natural_width_p);
			this.vfuncs = saved;
		}

		public override void get_preferred_height(
			float for_width,
			out float min_height_p,
			out float natural_height_p
		) {
			var hook = this.vfuncs.get(ActorVfuncIds.get_preferred_height_id);
			if (hook == null) {
				base.get_preferred_height(
					for_width, out min_height_p, out natural_height_p);
				GLib.debug("preferred-height base type=%s for=%g min=%g nat=%g",
					this.client_type_name != null ? this.client_type_name : "?",
					for_width, min_height_p, natural_height_p);
				return;
			}
			if (LayoutHooks.measure_height(
					hook, this, for_width,
					out min_height_p, out natural_height_p)) {
				return;
			}
			var saved = this.vfuncs;
			this.vfuncs = new Gee.HashMap<int, OLLMrpc.Live.Hook>();
			base.get_preferred_height(
				for_width, out min_height_p, out natural_height_p);
			this.vfuncs = saved;
			GLib.debug("preferred-height fallthrough type=%s for=%g min=%g nat=%g",
				this.client_type_name != null ? this.client_type_name : "?",
				for_width, min_height_p, natural_height_p);
		}

		public override void allocate(global::Clutter.ActorBox box)
		{
			var hook = this.vfuncs.get(ActorVfuncIds.allocate_id);
			if (hook == null) {
				base.allocate(box);
				return;
			}
			if (LayoutHooks.measure_allocate(hook, this, box)) {
				return;
			}
			var saved = this.vfuncs;
			this.vfuncs = new Gee.HashMap<int, OLLMrpc.Live.Hook>();
			base.allocate(box);
			this.vfuncs = saved;
		}

		[CCode (cname = "clutter_actor_allocate")]
		static extern void clutter_actor_allocate_public(
			global::Clutter.Actor actor,
			global::Clutter.ActorBox box
		);

		/**
		 * ''Gsr-Clutter-Actor.allocate_public'' — C {@code clutter_actor_allocate}
		 * (adjust_allocation then Class->allocate). GI
		 * {@code Clutter-Actor.allocate} hits klass->allocate and skips
		 * that wrapper (workspace-dot-align-smoke C).
		 */
		public void allocate_public(OLLMrpc.Request request, GLib.Bytes box_bytes)
		{
			var peer = request.connection.leases.get((int) request.lease_id) as Actor;
			if (peer == null || box_bytes.length < sizeof(global::Clutter.ActorBox)) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			global::Clutter.ActorBox box = *((global::Clutter.ActorBox*) box_bytes.get_data());
			clutter_actor_allocate_public(peer, box);
			request.reply(new OLLMrpc.Response());
		}

		/**
		 * ''Gsr-Clutter-Actor.base_preferred_width'' — St measure with hooks popped.
		 */
		public void base_preferred_width(
			OLLMrpc.Request request,
			double for_height
		) {
			var saved = this.vfuncs;
			this.vfuncs = new Gee.HashMap<int, OLLMrpc.Live.Hook>();
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
		 * ''Gsr-Clutter-Actor.base_preferred_height'' — see base_preferred_width.
		 */
		public void base_preferred_height(
			OLLMrpc.Request request,
			double for_width
		) {
			var saved = this.vfuncs;
			this.vfuncs = new Gee.HashMap<int, OLLMrpc.Live.Hook>();
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

		public override bool event(global::Clutter.Event clutter_event)
		{
			var hook = this.vfuncs.get(ActorVfuncIds.event_id);
			GLib.debug("type=%d actor=%s name=%s style=%s hook=%d",
				(int) clutter_event.get_type(),
				this.client_type_name != null ? this.client_type_name : "?",
				this.name != null ? this.name : "",
				this.get_style_class_name() != null ? this.get_style_class_name() : "",
				hook != null ? 1 : 0);
			if (hook == null) {
				/* Parent ClutterActorClass.event is NULL on global::St.Widget —
				 * Vala base.event would call through 0 (motion SIGSEGV). */
				return false;
			}
			if (LayoutHooks.measure_event(hook, this, clutter_event)) {
				return true;
			}
			return false;
		}

		public override bool captured_event(global::Clutter.Event clutter_event)
		{
			var hook = this.vfuncs.get(ActorVfuncIds.captured_event_id);
			GLib.debug("type=%d actor=%s name=%s style=%s hook=%d",
				(int) clutter_event.get_type(),
				this.client_type_name != null ? this.client_type_name : "?",
				this.name != null ? this.name : "",
				this.get_style_class_name() != null ? this.get_style_class_name() : "",
				hook != null ? 1 : 0);
			if (hook == null) {
				return false;
			}
			if (LayoutHooks.measure_event(hook, this, clutter_event)) {
				return true;
			}
			return false;
		}

		/**
		 * global::St.Widget::style-changed default handler (Class offset). Stock
		 * emit runs this; GJS {@code connect('style-changed')} needs the
		 * client Live.Hook (buttonbox-hpadding-smoke).
		 */
		public override void style_changed()
		{
			var hook = this.vfuncs.get(style_changed_id);
			if (hook != null) {
				LayoutHooks.measure_style_changed(hook, this);
			}
			base.style_changed();
		}

		/**
		 * ''Gsr-Clutter-Actor.pointer_click'' — stage coords; virtual pointer
		 * motion + primary press/release (B3 hit-test prove).
		 */
		public void pointer_click(OLLMrpc.Request request, double x, double y)
		{
			var backend = global::Clutter.get_default_backend();
			var seat = backend.get_default_seat();
			var virt = seat.create_virtual_device(
				global::Clutter.InputDeviceType.POINTER_DEVICE);
			if (virt == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR);
				return;
			}
			virt.notify_absolute_motion(0, x, y);
			virt.notify_button(1, global::Clutter.Button.PRIMARY,
				global::Clutter.ButtonState.PRESSED);
			virt.notify_button(2, global::Clutter.Button.PRIMARY,
				global::Clutter.ButtonState.RELEASED);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		/**
		 * ''Gsr-Clutter-Actor.fire_button_press'' — fire the leased peer's
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
			var hook = actor.vfuncs.get(ActorVfuncIds.event_id);
			if (hook == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			float ax = 0.0f, ay = 0.0f;
			actor.get_transformed_position(out ax, out ay);
			hook.emit(OLLMrpc.args("tiddu",
				hook.connection.export(actor),
				(int) global::Clutter.EventType.BUTTON_PRESS,
				(double) (ax + actor.get_width() / 2.0f),
				(double) (ay + actor.get_height() / 2.0f),
				(uint32) global::Clutter.Button.PRIMARY));
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		[CCode (cname = "clutter_actor_event")]
		private static extern bool clutter_actor_event(
			global::Clutter.Actor actor,
			unowned global::Clutter.Event event,
			bool capture
		);

		[CCode (cname = "gsr_clutter_event_key_insert", cheader_filename = "gsr-clutter-event-key.h")]
		private static extern global::Clutter.Event gsr_clutter_event_key_insert(
			global::Clutter.EventType type,
			uint32 keyval,
			global::Clutter.ModifierType modifiers
		);

		/**
		 * ''Gsr-Clutter-Actor.deliver_event'' — stock {@code clutter_actor_event}.
		 *
		 * The client event is Compact. When {@code clutter_get_current_event}
		 * is still that press (overview search re-delivers the stage key
		 * from inside the handler), use it so unicode and device stay.
		 * Otherwise build a synthetic key. Other types with no current
		 * event propagate.
		 */
		public void deliver_event(
			OLLMrpc.Request request,
			int event_type,
			bool capture,
			double x,
			double y,
			uint button,
			uint keyval,
			uint state
		) {
			var actor = request.connection.leases.get(
				(int) request.lease_id) as global::Clutter.Actor;
			if (actor == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var type = (global::Clutter.EventType) event_type;
			unowned var current = global::Clutter.get_current_event();
			var stop = false;
			if (current != null && Actor.event_matches(current, type, button, keyval)) {
				stop = clutter_actor_event(actor, current, capture);
			} else if (type == global::Clutter.EventType.KEY_PRESS
					|| type == global::Clutter.EventType.KEY_RELEASE) {
				var ev = gsr_clutter_event_key_insert(
					type, keyval, (global::Clutter.ModifierType) state);
				if (ev != null) {
					stop = clutter_actor_event(actor, ev, capture);
					ev.free();
				}
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", stop),
			});
		}

		static bool event_matches(
			global::Clutter.Event current,
			global::Clutter.EventType type,
			uint button,
			uint keyval
		) {
			if (current.get_type() != type) {
				return false;
			}
			switch (type) {
				case global::Clutter.EventType.KEY_PRESS:
				case global::Clutter.EventType.KEY_RELEASE:
					return current.get_key_symbol() == keyval;
				case global::Clutter.EventType.BUTTON_PRESS:
				case global::Clutter.EventType.BUTTON_RELEASE:
				case global::Clutter.EventType.PAD_BUTTON_PRESS:
				case global::Clutter.EventType.PAD_BUTTON_RELEASE:
					return current.get_button() == button;
				default:
					return true;
			}
		}

		/**
		 * ''Gsr-Clutter-Actor.fire_key'' — nested B2 prove. Virtual keyboard
		 * keyval (+ optional Super/Ctrl/Alt/Shift) through mutter grabs.
		 * Not stock Shell; same seat pattern as {@link pointer_click}.
		 */
		public void fire_key(
			OLLMrpc.Request request,
			uint keyval,
			uint modifiers
		) {
			var backend = global::Clutter.get_default_backend();
			var seat = backend.get_default_seat();
			var virt = seat.create_virtual_device(
				global::Clutter.InputDeviceType.KEYBOARD_DEVICE);
			if (virt == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR);
				return;
			}
			var mods = (global::Clutter.ModifierType) modifiers;
			if ((mods & global::Clutter.ModifierType.SUPER_MASK) != 0) {
				virt.notify_keyval(0, global::Clutter.Key.Super_L,
					global::Clutter.KeyState.PRESSED);
			}
			if ((mods & global::Clutter.ModifierType.CONTROL_MASK) != 0) {
				virt.notify_keyval(0, global::Clutter.Key.Control_L,
					global::Clutter.KeyState.PRESSED);
			}
			if ((mods & global::Clutter.ModifierType.MOD1_MASK) != 0) {
				virt.notify_keyval(0, global::Clutter.Key.Alt_L,
					global::Clutter.KeyState.PRESSED);
			}
			if ((mods & global::Clutter.ModifierType.SHIFT_MASK) != 0) {
				virt.notify_keyval(0, global::Clutter.Key.Shift_L,
					global::Clutter.KeyState.PRESSED);
			}
			virt.notify_keyval(0, keyval, global::Clutter.KeyState.PRESSED);
			virt.notify_keyval(0, keyval, global::Clutter.KeyState.RELEASED);
			if ((mods & global::Clutter.ModifierType.SHIFT_MASK) != 0) {
				virt.notify_keyval(0, global::Clutter.Key.Shift_L,
					global::Clutter.KeyState.RELEASED);
			}
			if ((mods & global::Clutter.ModifierType.MOD1_MASK) != 0) {
				virt.notify_keyval(0, global::Clutter.Key.Alt_L,
					global::Clutter.KeyState.RELEASED);
			}
			if ((mods & global::Clutter.ModifierType.CONTROL_MASK) != 0) {
				virt.notify_keyval(0, global::Clutter.Key.Control_L,
					global::Clutter.KeyState.RELEASED);
			}
			if ((mods & global::Clutter.ModifierType.SUPER_MASK) != 0) {
				virt.notify_keyval(0, global::Clutter.Key.Super_L,
					global::Clutter.KeyState.RELEASED);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
