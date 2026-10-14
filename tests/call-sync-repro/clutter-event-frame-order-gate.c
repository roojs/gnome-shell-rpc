/*
 * Stock Clutter event/frame order. A ClickAction long-press cancellation
 * schedules a frame during button release. Both clicked handlers must finish
 * before before-update, and the input callbacks must retain current_event.
 *
 *   meson compile -C build clutter-event-frame-order-gate
 *   timeout 20 ./build/tests/call-sync-repro/clutter-event-frame-order-gate
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

static ClutterActor *stage;
static int order;
static int cancel_order;
static int clicked_first_order;
static int clicked_second_order;
static int frame_order;
static gboolean cancel_current;
static gboolean clicked_current;
static gboolean frame_current;
static gboolean frame_scheduled;
static gboolean followup_probe;
static int followup_frames;

static gboolean
on_long_press (
	ClutterClickAction *action,
	ClutterActor *actor,
	ClutterLongPressState state,
	gpointer data)
{
	(void) action;
	(void) actor;
	(void) data;
	if (state == CLUTTER_LONG_PRESS_CANCEL) {
		cancel_order = ++order;
		cancel_current = clutter_get_current_event () != NULL;
		frame_scheduled = TRUE;
		clutter_stage_schedule_update (CLUTTER_STAGE (stage));
	}
	return TRUE;
}

static void
on_clicked_first (ClutterClickAction *action, ClutterActor *actor, gpointer data)
{
	(void) action;
	(void) actor;
	(void) data;
	clicked_first_order = ++order;
	clicked_current = clutter_get_current_event () != NULL;
}

static void
on_clicked_second (ClutterClickAction *action, ClutterActor *actor, gpointer data)
{
	(void) action;
	(void) actor;
	(void) data;
	clicked_second_order = ++order;
	clicked_current = clicked_current
		&& clutter_get_current_event () != NULL;
}

static void
on_before_update (
	ClutterStage *actor,
	gpointer view,
	gpointer frame,
	gpointer data)
{
	(void) view;
	(void) frame;
	(void) data;
	if (followup_probe) {
		followup_frames++;
		if (followup_frames == 1)
			clutter_stage_schedule_update (actor);
		return;
	}
	if (!frame_scheduled || frame_order != 0)
		return;
	frame_order = ++order;
	frame_current = clutter_get_current_event () != NULL;
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
		"clutter-event-frame-order-gate",
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
	ClutterActor *child;
	ClutterAction *click_action;
	ClutterVirtualInputDevice *pointer;

	(void) argc;
	(void) argv;

	context = meta_create_context ("clutter-event-frame-order-gate");
	meta_context_set_plugin_gtype (context, gate_plugin_get_type ());
	if (!meta_context_configure (context, &n, &av, &error)
			|| !meta_context_setup (context, &error)
			|| !meta_context_start (context, &error)) {
		g_printerr ("FAIL clutter-event-frame-order-gate: setup %s\n",
			error == NULL ? "unknown" : error->message);
		return 1;
	}

	backend = meta_context_get_backend (context);
	stage = meta_backend_get_stage (backend);
	seat = clutter_backend_get_default_seat (clutter_get_default_backend ());
	child = clutter_actor_new ();
	clutter_actor_set_reactive (child, TRUE);
	clutter_actor_set_position (child, 100, 100);
	clutter_actor_set_size (child, 80, 40);
	clutter_actor_add_child (stage, child);
	click_action = clutter_click_action_new ();
	clutter_actor_add_action (child, click_action);
	g_signal_connect (
		click_action, "long-press", G_CALLBACK (on_long_press), NULL);
	g_signal_connect (
		click_action, "clicked", G_CALLBACK (on_clicked_first), NULL);
	g_signal_connect (
		click_action, "clicked", G_CALLBACK (on_clicked_second), NULL);
	g_signal_connect (
		stage, "before-update", G_CALLBACK (on_before_update), NULL);
	clutter_actor_show (stage);
	clutter_actor_show (child);
	pump (200);

	pointer = clutter_seat_create_virtual_device (
		seat, CLUTTER_POINTER_DEVICE);
	clutter_virtual_input_device_notify_absolute_motion (
		pointer, g_get_monotonic_time (), 120, 110);
	pump (50);
	clutter_virtual_input_device_notify_button (
		pointer, g_get_monotonic_time (),
		CLUTTER_BUTTON_PRIMARY, CLUTTER_BUTTON_STATE_PRESSED);
	pump (50);
	clutter_virtual_input_device_notify_button (
		pointer, g_get_monotonic_time (),
		CLUTTER_BUTTON_PRIMARY, CLUTTER_BUTTON_STATE_RELEASED);
	pump (100);

	if (cancel_order == 0 || clicked_first_order == 0
			|| clicked_second_order == 0 || frame_order == 0) {
		g_printerr (
			"FAIL clutter-event-frame-order-gate: missing cancel=%d first=%d second=%d frame=%d\n",
			cancel_order, clicked_first_order, clicked_second_order, frame_order);
		return 1;
	}
	if (!(cancel_order < clicked_first_order
				&& clicked_first_order < clicked_second_order
				&& clicked_second_order < frame_order)) {
		g_printerr (
			"FAIL clutter-event-frame-order-gate: order cancel=%d first=%d second=%d frame=%d\n",
			cancel_order, clicked_first_order, clicked_second_order, frame_order);
		return 1;
	}
	if (!cancel_current || !clicked_current || frame_current) {
		g_printerr (
			"FAIL clutter-event-frame-order-gate: current cancel=%d clicked=%d frame=%d\n",
			cancel_current, clicked_current, frame_current);
		return 1;
	}

	followup_probe = TRUE;
	clutter_stage_schedule_update (CLUTTER_STAGE (stage));
	pump (100);
	if (followup_frames < 2) {
		g_printerr (
			"FAIL clutter-event-frame-order-gate: follow-up frames=%d\n",
			followup_frames);
		return 1;
	}

	g_printerr (
		"PASS clutter-event-frame-order-gate: cancel=%d first=%d second=%d frame=%d current=1,1,0 follow-up=%d\n",
		cancel_order, clicked_first_order, clicked_second_order, frame_order,
		followup_frames);
	return 0;
}
