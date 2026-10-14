/*
 * Drag long-press cancel. Press, then several motions still inside the
 * actor, then one motion outside, with no main-loop turn between them.
 * The hand logs cancel on a synthesized leave and see no current event.
 *
 *   meson compile -C build tests/call-sync-repro/clutter-drag-leave-gate
 *   timeout 20 ./build/tests/call-sync-repro/clutter-drag-leave-gate
 */
#include <clutter/clutter.h>
#include <meta/meta-backend.h>
#include <meta/meta-context.h>
#include <meta/meta-plugin.h>

typedef struct _GatePlugin {
	MetaPlugin parent;
} GatePlugin;

typedef struct _GatePluginClass {
	MetaPluginClass parent_class;
} GatePluginClass;

G_DEFINE_TYPE (GatePlugin, gate_plugin, META_TYPE_PLUGIN)

static void
gate_plugin_class_init (GatePluginClass *klass)
{
	(void) klass;
}

static void
gate_plugin_init (GatePlugin *self)
{
	(void) self;
}

static int cancel_count;
static gboolean cancel_current;
static int cancel_type;

extern void _clutter_stage_process_queued_events (ClutterStage *stage);

static gboolean
flush_queued_motion (
	const ClutterEvent *event,
	ClutterActor *actor,
	gpointer data)
{
	ClutterActor *stage;

	(void) event;
	(void) data;
	if (actor == NULL)
		return CLUTTER_EVENT_PROPAGATE;
	stage = clutter_actor_get_stage (actor);
	if (stage != NULL)
		_clutter_stage_process_queued_events (CLUTTER_STAGE (stage));
	return CLUTTER_EVENT_PROPAGATE;
}

static gboolean
on_long_press (
	ClutterClickAction *action,
	ClutterActor *actor,
	ClutterLongPressState state,
	gpointer data)
{
	const ClutterEvent *event;

	(void) action;
	(void) actor;
	(void) data;
	if (state != CLUTTER_LONG_PRESS_CANCEL)
		return TRUE;
	cancel_count++;
	event = clutter_get_current_event ();
	cancel_current = event != NULL;
	cancel_type = event == NULL ? -1 : (int) clutter_event_type (event);
	return TRUE;
}

static void
pump (int ms)
{
	GMainLoop *loop = g_main_loop_new (NULL, FALSE);
	g_timeout_add (ms, (GSourceFunc) g_main_loop_quit, loop);
	g_main_loop_run (loop);
	g_main_loop_unref (loop);
}

int
main (int argc, char **argv)
{
	char *args[] = {
		"clutter-drag-leave-gate",
		"--headless",
		"--no-x11",
		"--virtual-monitor",
		"800x600",
		NULL,
	};
	int n = 5;
	char **av = args;
	g_autoptr (GError) error = NULL;
	MetaContext *context;
	MetaBackend *backend;
	ClutterSeat *seat;
	ClutterActor *stage;
	ClutterActor *child;
	ClutterAction *click_action;
	ClutterVirtualInputDevice *pointer;
	int i;

	(void) argc;
	(void) argv;

	context = meta_create_context ("clutter-drag-leave-gate");
	meta_context_set_plugin_gtype (context, gate_plugin_get_type ());
	if (!meta_context_configure (context, &n, &av, &error)
			|| !meta_context_setup (context, &error)
			|| !meta_context_start (context, &error)) {
		g_printerr ("FAIL clutter-drag-leave-gate: setup %s\n",
			error == NULL ? "unknown" : error->message);
		return 1;
	}

	backend = meta_context_get_backend (context);
	stage = meta_backend_get_stage (backend);
	seat = clutter_backend_get_default_seat (clutter_get_default_backend ());
	child = clutter_actor_new ();
	clutter_actor_set_reactive (child, TRUE);
	clutter_actor_set_position (child, 100, 100);
	clutter_actor_set_size (child, 200, 120);
	clutter_actor_add_child (stage, child);
	click_action = clutter_click_action_new ();
	clutter_actor_add_action (child, click_action);
	g_signal_connect (
		click_action, "long-press", G_CALLBACK (on_long_press), NULL);
	clutter_actor_show (stage);
	clutter_actor_show (child);
	clutter_event_add_filter (NULL, flush_queued_motion, NULL, NULL);
	pump (200);

	pointer = clutter_seat_create_virtual_device (
		seat, CLUTTER_POINTER_DEVICE);
	clutter_virtual_input_device_notify_absolute_motion (
		pointer, g_get_monotonic_time (), 150, 140);
	pump (50);
	clutter_virtual_input_device_notify_button (
		pointer, g_get_monotonic_time (),
		CLUTTER_BUTTON_PRIMARY, CLUTTER_BUTTON_STATE_PRESSED);
	pump (50);

	/*
	 * No main-loop turn. The hand session queued the drag motions and
	 * the leave was emitted before any of those motions reached the action.
	 * The filter above delivers the queued motion first.
	 */
	for (i = 1; i <= 4; i++) {
		clutter_virtual_input_device_notify_absolute_motion (
			pointer, g_get_monotonic_time (), 150 + (i * 10), 140);
	}
	clutter_virtual_input_device_notify_absolute_motion (
		pointer, g_get_monotonic_time (), 400, 140);
	pump (100);

	if (cancel_count == 0) {
		g_printerr ("FAIL clutter-drag-leave-gate: no long-press cancel\n");
		return 1;
	}
	if (cancel_current && cancel_type == (int) CLUTTER_MOTION) {
		g_printerr (
			"PASS clutter-drag-leave-gate: motion cancel type=%d count=%d\n",
			cancel_type, cancel_count);
		return 0;
	}
	g_printerr (
		"FAIL clutter-drag-leave-gate: current=%d type=%d count=%d\n",
		cancel_current, cancel_type, cancel_count);
	return 1;
}
