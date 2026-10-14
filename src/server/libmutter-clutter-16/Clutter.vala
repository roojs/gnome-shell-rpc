/**
 * Gsr-Clutter — namespace Clutter functions that need packed returns
 * (Compact {@link global::Clutter.Event} cannot go through Gi.dispatch).
 *
 * Stock {@code global::Clutter} is qualified because this class is also named global::Clutter.
 */
namespace Gsr.Server.Clutter
{
	public class Clutter : GLib.Object
	{
		private static int queued_flush_depth;
		private static bool flush_again;
		private static global::Clutter.Stage? flush_stage;
		/* Leave and other crossings are emitted with no current event.
		 * dnd.js reads get_current_event() inside that long-press. */
		private static global::Clutter.Event? open_event;

		[CCode (cname = "clutter_event_copy", cheader_filename = "clutter/clutter.h")]
		private static extern global::Clutter.Event copy_clutter_event(global::Clutter.Event event);

		/**
		 * Mutter's {@code _clutter_stage_process_queued_events} (clutter-stage-private.h, defined in clutter-stage.c).
		 * Delivers events already queued on the stage. The Vala name is that symbol. This tree only declares it.
		 */
		[CCode (cname = "_clutter_stage_process_queued_events", cheader_filename = "gsr-clutter-event-key.h")]
		private static extern void _clutter_stage_process_queued_events(global::Clutter.Stage stage);

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-Clutter", typeof(Clutter),
				"get_current_event", "",
				"event_get", "",
				"event_add_filter", "tt",
				"event_remove_filter", "u",
				null
			);
			OLLMrpc.Request.register_live("Gsr-Clutter", new Clutter());
			/* A pointer burst queues motions. Delivering one blocks on the
			 * client, and the main loop takes the rest of the burst while
			 * that delivery is still on the stack. Flush again when it
			 * returns, or the long-press timeout runs first and the drag
			 * never starts. */
			global::Clutter.Event.add_filter(null, (event, event_actor) => {
				if (global::Clutter.get_current_event() == null) {
					open_event = copy_clutter_event(event);
				}
				if (event_actor != null) {
					var stage = event_actor.get_stage();
					if (stage != null) {
						flush_stage = (global::Clutter.Stage) stage;
					}
				}
				if (flush_stage == null) {
					return false;
				}
				if (queued_flush_depth > 0) {
					flush_again = true;
					return false;
				}
				do {
					flush_again = false;
					queued_flush_depth++;
					_clutter_stage_process_queued_events(flush_stage);
					queued_flush_depth--;
				} while (flush_again);
				return false;
			});
		}

		/**
		 * Pack stock {@code clutter_get_current_event} as
		 * type / x / y / button / state / keyval / related actor.
		 * Empty args means no event. Related actor is uint64 0 when there is none.
		 */
		public void get_current_event(OLLMrpc.Request request)
		{
			unowned var ev = global::Clutter.get_current_event();
			if (ev == null) {
				ev = open_event;
			}
			this.reply_event(request, ev);
		}

		/**
		 * Pop and pack stock {@code clutter_event_get}.
		 */
		public void event_get(OLLMrpc.Request request)
		{
			var ev = global::Clutter.Event.get();
			this.reply_event(request, ev);
		}

		/**
		 * Install the real compositor-side Clutter event filter and relay each
		 * invocation to the client callback. Its boolean reply preserves
		 * stop/propagate behavior before Clutter emits the event.
		 */
		public void event_add_filter(
			OLLMrpc.Request request,
			uint64 stage_lid,
			uint64 callback_id
		) {
			if (!request.connection.callbacks.has_key((int) callback_id)) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			global::Clutter.Stage? stage = null;
			if (stage_lid != 0) {
				stage = request.connection.leases.get((int) stage_lid)
					as global::Clutter.Stage;
				if (stage == null) {
					request.connection.reply_error(request,
						(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
					return;
				}
			}
			var row = request.connection.callbacks.get((int) callback_id);
			var filter_id = global::Clutter.Event.add_filter(
				stage, (event, event_actor) => {
					var fields = this.pack_event(event);
					if (event_actor == null) {
						fields.add(OLLMrpc.val("t", (uint64) 0));
					} else {
						fields.add(OLLMrpc.val("o", event_actor));
					}
					row.emit(fields);
					return row.reply_args.size > 0
						&& row.reply_args.get(0).get_boolean();
				});
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("u", filter_id),
			});
		}

		public void event_remove_filter(OLLMrpc.Request request, uint id)
		{
			global::Clutter.Event.remove_filter(id);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		private void reply_event(
			OLLMrpc.Request request,
			global::Clutter.Event? ev
		) {
			if (ev == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = this.pack_event(ev),
			});
		}

		private Gee.ArrayList<GLib.Value?> pack_event(global::Clutter.Event ev)
		{
			float x = 0f, y = 0f;
			ev.get_coords(out x, out y);
			var et = ev.get_type();
			uint32 button = 0;
			uint key = 0;
			global::Clutter.Actor? related = null;
			switch (et) {
				case global::Clutter.EventType.BUTTON_PRESS:
				case global::Clutter.EventType.BUTTON_RELEASE:
				case global::Clutter.EventType.PAD_BUTTON_PRESS:
				case global::Clutter.EventType.PAD_BUTTON_RELEASE:
					button = ev.get_button();
					break;
				case global::Clutter.EventType.KEY_PRESS:
				case global::Clutter.EventType.KEY_RELEASE:
					key = ev.get_key_symbol();
					break;
				case global::Clutter.EventType.ENTER:
				case global::Clutter.EventType.LEAVE:
					related = ev.get_related();
					break;
				default:
					break;
			}
			var args = OLLMrpc.args("iddduu",
				(int) et, (double) x, (double) y, button,
				(uint) ev.get_state(), key);
			if (related == null) {
				args.add(OLLMrpc.val("t", (uint64) 0));
			} else {
				args.add(OLLMrpc.val("o", related));
			}
			var scroll = 0u;
			if (et == global::Clutter.EventType.SCROLL) {
				scroll = (uint) ev.get_scroll_source();
			}
			args.add(OLLMrpc.val("u", scroll));
			var device_type = -1;
			unowned var device = ev.get_source_device();
			if (device != null) {
				device_type = (int) device.get_device_type();
			}
			args.add(OLLMrpc.val("i", device_type));
			args.add(OLLMrpc.val("u", ev.get_time()));
			return args;
		}
	}
}
