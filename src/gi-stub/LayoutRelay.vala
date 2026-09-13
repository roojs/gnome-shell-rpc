/**
 * Client layout relay — detect Class measure slots, register GType flags,
 * mint Helper-Actor with only the needed live callbacks.
 */
namespace GnomeShellRpc.GiStub
{
	public class LayoutRelay
	{
		/** Actor whose live preferred/allocate hook is running; null when idle. */
		public static Clutter.Actor? hook_actor;
		/** No JS override → fall through to Helper-Actor.base_preferred_* / base.allocate. */
		public static bool use_base;
		static Gee.HashMap<GLib.Type, uint32>? caps_by_type;

		[CCode (cname = "gsr_actor_class_measure_slots", cheader_filename = "gsr-actor-class-slots.h")]
		static extern void class_measure_slots(
			GLib.Type type,
			out void* get_preferred_width,
			out void* get_preferred_height,
			out void* allocate);

		public static void attach(Clutter.Actor self)
		{
			var type = self.get_type();
			var flags = ensure_registered(type);
			uint64 preferred_width_id = 0;
			uint64 preferred_height_id = 0;
			uint64 allocate_id = 0;
			if ((flags & 1) != 0) {
				preferred_width_id = bind_preferred_width(self);
			}
			if ((flags & 2) != 0) {
				preferred_height_id = bind_preferred_height(self);
			}
			if ((flags & 4) != 0) {
				allocate_id = bind_allocate(self);
			}
			var response = GnomeShellRpc.call_value(
				"Helper-Actor.create", null,
				OLLMrpc.args("sttt", type.name(),
					preferred_width_id, preferred_height_id, allocate_id));
			self.rpc_lid = response.args.get(0).get_uint64();
		}

		static uint32 ensure_registered(GLib.Type type)
		{
			if (caps_by_type == null) {
				caps_by_type = new Gee.HashMap<GLib.Type, uint32>();
			}
			if (caps_by_type.has_key(type)) {
				return caps_by_type.get(type);
			}
			void* pw, ph, al, bpw, bph, bal;
			class_measure_slots(type, out pw, out ph, out al);
			/* St.Widget GType — clutter lib has no St pkg; name is enough at attach. */
			var baseline = GLib.Type.from_name("StWidget");
			if (baseline == GLib.Type.INVALID) {
				baseline = typeof(Clutter.Actor);
			}
			class_measure_slots(baseline, out bpw, out bph, out bal);
			uint32 flags = (pw != bpw ? 1 : 0)
				+ (ph != bph ? 2 : 0)
				+ (al != bal ? 4 : 0);
			GnomeShellRpc.call_value(
				"Helper-Actor.register_vfuncs", null,
				OLLMrpc.args("su", type.name(), flags));
			caps_by_type.set(type, flags);
			return flags;
		}

		static uint64 bind_preferred_width(Clutter.Actor self)
		{
			return Runtime.callback_bind((call) => {
				float min = 0.0f, nat = 0.0f;
				use_base = false;
				hook_actor = self;
				try {
					self.get_preferred_width_vfunc(
						(float) call.args.get(1).get_double(),
						out min, out nat);
				} finally {
					hook_actor = null;
				}
				if (use_base) {
					/* Keep this ask open: server measure now (children
					 * asked while we still wait). Then return real sizes. */
					var for_height = call.args.get(1).get_double();
					var response = GnomeShellRpc.call_value(
						"Helper-Actor.base_preferred_width", self,
						OLLMrpc.args("d", for_height));
					return OLLMrpc.args("dd",
						response.args.get(0).get_double(),
						response.args.get(1).get_double());
				}
				return OLLMrpc.args("dd", (double) min, (double) nat);
			});
		}

		static uint64 bind_preferred_height(Clutter.Actor self)
		{
			return Runtime.callback_bind((call) => {
				float min = 0.0f, nat = 0.0f;
				use_base = false;
				hook_actor = self;
				try {
					self.get_preferred_height_vfunc(
						(float) call.args.get(1).get_double(),
						out min, out nat);
				} finally {
					hook_actor = null;
				}
				if (use_base) {
					var for_width = call.args.get(1).get_double();
					var response = GnomeShellRpc.call_value(
						"Helper-Actor.base_preferred_height", self,
						OLLMrpc.args("d", for_width));
					return OLLMrpc.args("dd",
						response.args.get(0).get_double(),
						response.args.get(1).get_double());
				}
				return OLLMrpc.args("dd", (double) min, (double) nat);
			});
		}

		static uint64 bind_allocate(Clutter.Actor self)
		{
			return Runtime.callback_bind((call) => {
				var box = Clutter.ActorBox();
				box.x1 = (float) call.args.get(1).get_double();
				box.y1 = (float) call.args.get(2).get_double();
				box.x2 = (float) call.args.get(3).get_double();
				box.y2 = (float) call.args.get(4).get_double();
				use_base = false;
				hook_actor = self;
				try {
					self.allocate_vfunc(box);
				} finally {
					hook_actor = null;
				}
				if (use_base) {
					return OLLMrpc.args("b", true);
				}
				return OLLMrpc.args("b", false);
			});
		}
	}
}
