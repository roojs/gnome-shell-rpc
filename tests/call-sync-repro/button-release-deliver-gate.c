/*
 * Headless stage click. A reactive child must see both
 * button-press-event and button-release-event. Then the same
 * click under a stage grab (overview pushModal grabs the stage).
 *
 *   meson compile -C build button-release-deliver-gate
 *   timeout 20 ./build/tests/call-sync-repro/button-release-deliver-gate
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

static int press_count;
static int release_count;
static int captured_count;

static gboolean
on_captured (ClutterActor *actor, ClutterEvent *event, gpointer data)
{
	(void) actor;
	(void) data;
	if (clutter_event_type (event) == CLUTTER_BUTTON_PRESS
			|| clutter_event_type (event) == CLUTTER_BUTTON_RELEASE) {
		captured_count++;
	}
	return CLUTTER_EVENT_PROPAGATE;
}

static gboolean
on_press (ClutterActor *actor, ClutterEvent *event, gpointer data)
{
	(void) actor;
	(void) event;
	(void) data;
	press_count++;
	return CLUTTER_EVENT_PROPAGATE;
}

static gboolean
on_release (ClutterActor *actor, ClutterEvent *event, gpointer data)
{
	(void) actor;
	(void) event;
	(void) data;
	release_count++;
	return CLUTTER_EVENT_PROPAGATE;
}

static void
pump (int ms)
{
	GMainLoop *loop = g_main_loop_new (NULL, FALSE);
	g_timeout_add (ms, (GSourceFunc) g_main_loop_quit, loop);
	g_main_loop_run (loop);
	g_main_loop_unref (loop);
}

static void
click_at (ClutterVirtualInputDevice *pointer, float x, float y)
{
	clutter_virtual_input_device_notify_absolute_motion (
		pointer, g_get_monotonic_time (), x, y);
	pump (50);
	clutter_virtual_input_device_notify_button (
		pointer, g_get_monotonic_time (),
		CLUTTER_BUTTON_PRIMARY, CLUTTER_BUTTON_STATE_PRESSED);
	pump (50);
	clutter_virtual_input_device_notify_button (
		pointer, g_get_monotonic_time (),
		CLUTTER_BUTTON_PRIMARY, CLUTTER_BUTTON_STATE_RELEASED);
	pump (50);
}

static int
expect (const char *label, int press_before, int release_before)
{
	int press = press_count - press_before;
	int release = release_count - release_before;
	if (press < 1 || release < 1) {
		g_printerr (
			"FAIL button-release-deliver-gate: %s press=%d release=%d captured=%d\n",
			label, press, release, captured_count);
		return 1;
	}
	g_printerr (
		"ok %s press=%d release=%d\n",
		label, press, release);
	return 0;
}

int
main (int argc, char **argv)
{
	char *args[] = {
		"button-release-deliver-gate",
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
	ClutterVirtualInputDevice *pointer;
	ClutterGrab *grab;
	int failed = 0;
	int mark_press;
	int mark_release;

	(void) argc;
	(void) argv;

	context = meta_create_context ("button-release-deliver-gate");
	meta_context_set_plugin_gtype (context, gate_plugin_get_type ());
	if (!meta_context_configure (context, &n, &av, &error)) {
		g_printerr ("FAIL button-release-deliver-gate: configure %s\n",
			error->message);
		return 1;
	}
	if (!meta_context_setup (context, &error)) {
		g_printerr ("FAIL button-release-deliver-gate: setup %s\n",
			error->message);
		return 1;
	}
	if (!meta_context_start (context, &error)) {
		g_printerr ("FAIL button-release-deliver-gate: start %s\n",
			error->message);
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
	clutter_actor_show (stage);
	clutter_actor_show (child);
	g_signal_connect (stage, "captured-event", G_CALLBACK (on_captured), NULL);
	g_signal_connect (child, "button-press-event", G_CALLBACK (on_press), NULL);
	g_signal_connect (child, "button-release-event", G_CALLBACK (on_release), NULL);
	pump (200);
	{
		ClutterActor *picked = clutter_stage_get_actor_at_pos (
			CLUTTER_STAGE (stage), CLUTTER_PICK_REACTIVE, 120, 110);
		g_printerr (
			"stage mapped=%d child mapped=%d visible=%d realized=%d size=%.0fx%.0f picked=%s\n",
			clutter_actor_is_mapped (stage),
			clutter_actor_is_mapped (child),
			clutter_actor_is_visible (child),
			clutter_actor_is_realized (child),
			clutter_actor_get_width (child),
			clutter_actor_get_height (child),
			picked == NULL ? "null" : G_OBJECT_TYPE_NAME (picked));
	}

	pointer = clutter_seat_create_virtual_device (
		seat, CLUTTER_POINTER_DEVICE);
	mark_press = press_count;
	mark_release = release_count;
	click_at (pointer, 120, 110);
	failed |= expect ("plain", mark_press, mark_release);

	grab = clutter_stage_grab (CLUTTER_STAGE (stage), stage);
	mark_press = press_count;
	mark_release = release_count;
	click_at (pointer, 120, 110);
	failed |= expect ("stage-grab", mark_press, mark_release);
	clutter_grab_dismiss (grab);

	/*
	 * A reactive sibling above the child is the pick target.
	 * Stage captured-event still runs. The child sees neither
	 * press nor release. That is the Weston fourth click shape.
	 */
	{
		ClutterActor *cover = clutter_actor_new ();
		int cover_press;
		int cover_release;
		clutter_actor_set_reactive (cover, TRUE);
		clutter_actor_set_position (cover, 0, 0);
		clutter_actor_set_size (cover, 800, 600);
		clutter_actor_add_child (stage, cover);
		clutter_actor_show (cover);
		pump (50);
		cover_press = press_count;
		cover_release = release_count;
		captured_count = 0;
		click_at (pointer, 120, 110);
		if ((press_count - cover_press) != 0
				|| (release_count - cover_release) != 0
				|| captured_count < 2) {
			g_printerr (
				"FAIL button-release-deliver-gate: cover child press=%d release=%d captured=%d\n",
				press_count - cover_press,
				release_count - cover_release,
				captured_count);
			failed = 1;
		} else {
			g_printerr (
				"ok cover child press=0 release=0 captured=%d\n",
				captured_count);
		}
	}

	if (failed) {
		return 1;
	}
	g_printerr ("PASS button-release-deliver-gate\n");
	return 0;
}
