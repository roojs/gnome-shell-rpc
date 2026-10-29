/*
 * The crash-screen Log Out text from SpawnClient.on_crash.
 * Headless. Same actor: ClutterText, reactive, AlignConstraint on
 * X, translation (-16, 12). Press and release must arrive. Enter
 * sets META_CURSOR_POINTER and leave sets META_CURSOR_DEFAULT, and
 * the cursor sprite must change.
 *
 *   meson compile -C build tests/call-sync-repro/logout-text-pointer-gate
 *   timeout 20 ./build/tests/call-sync-repro/logout-text-pointer-gate
 */
#include <clutter/clutter.h>
#define __CLUTTER_H_INSIDE__
#include <clutter/pango/clutter-text.h>
#undef __CLUTTER_H_INSIDE__
#include <cogl/cogl.h>
#include <meta/meta-backend.h>
#include <meta/meta-context.h>
#include <meta/meta-cursor-tracker.h>
#include <meta/meta-plugin.h>
#include <meta/display.h>

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
static int enter_count;
static MetaDisplay *cursor_display;

static void
pick_hidden (ClutterActor *actor, ClutterPickContext *pick_context)
{
	if (g_object_get_data (G_OBJECT (actor), "shell-hidden-from-pick")) {
		return;
	}
	g_signal_chain_from_overridden_handler (actor, pick_context);
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
	return CLUTTER_EVENT_STOP;
}

static gboolean
on_enter (ClutterActor *actor, ClutterEvent *event, gpointer data)
{
	(void) actor;
	(void) event;
	(void) data;
	enter_count++;
	return CLUTTER_EVENT_PROPAGATE;
}

static gboolean
on_enter_pointer (ClutterActor *actor, ClutterEvent *event, gpointer data)
{
	(void) actor;
	(void) event;
	(void) data;
	meta_display_set_cursor (cursor_display, META_CURSOR_POINTER);
	return CLUTTER_EVENT_PROPAGATE;
}

static gboolean
on_leave_default (ClutterActor *actor, ClutterEvent *event, gpointer data)
{
	(void) actor;
	(void) event;
	(void) data;
	meta_display_set_cursor (cursor_display, META_CURSOR_DEFAULT);
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

int
main (int argc, char **argv)
{
	char *args[] = {
		"logout-text-pointer-gate",
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
	MetaDisplay *display;
	MetaCursorTracker *tracker;
	ClutterSeat *seat;
	ClutterActor *stage;
	ClutterActor *backdrop;
	ClutterActor *logout;
	ClutterVirtualInputDevice *pointer;
	CoglColor black;
	CoglColor white;
	CoglTexture *sprite_before;
	CoglTexture *sprite_hover;
	CoglTexture *sprite_away;
	ClutterActor *picked;
	float x = 0;
	float y = 0;
	float w;
	float h;
	int failed = 0;

	(void) argc;
	(void) argv;

	context = meta_create_context ("logout-text-pointer-gate");
	meta_context_set_plugin_gtype (context, gate_plugin_get_type ());
	if (!meta_context_configure (context, &n, &av, &error)) {
		g_printerr ("FAIL logout-text-pointer-gate: configure %s\n",
			error->message);
		return 1;
	}
	if (!meta_context_setup (context, &error)) {
		g_printerr ("FAIL logout-text-pointer-gate: setup %s\n",
			error->message);
		return 1;
	}
	if (!meta_context_start (context, &error)) {
		g_printerr ("FAIL logout-text-pointer-gate: start %s\n",
			error->message);
		return 1;
	}

	backend = meta_context_get_backend (context);
	display = meta_context_get_display (context);
	cursor_display = display;
	stage = meta_backend_get_stage (backend);
	tracker = meta_backend_get_cursor_tracker (backend);
	g_signal_override_class_handler ("pick", CLUTTER_TYPE_ACTOR,
		G_CALLBACK (pick_hidden));
	seat = clutter_backend_get_default_seat (clutter_get_default_backend ());

	cogl_color_init_from_4f (&black, 0.0f, 0.0f, 0.0f, 1.0f);
	cogl_color_init_from_4f (&white, 1.0f, 1.0f, 1.0f, 1.0f);

	backdrop = clutter_actor_new ();
	clutter_actor_set_background_color (backdrop, &black);
	clutter_actor_add_constraint (backdrop,
		clutter_bind_constraint_new (stage, CLUTTER_BIND_SIZE, 0));
	clutter_actor_insert_child_below (stage, backdrop, NULL);

	logout = clutter_text_new ();
	clutter_text_set_text (CLUTTER_TEXT (logout), "Log Out");
	clutter_text_set_font_name (CLUTTER_TEXT (logout), "Sans Bold 12");
	clutter_text_set_color (CLUTTER_TEXT (logout), &white);
	clutter_text_set_selectable (CLUTTER_TEXT (logout), FALSE);
	clutter_actor_set_reactive (logout, TRUE);
	clutter_actor_set_translation (logout, -16.0f, 12.0f, 0.0f);
	clutter_actor_add_constraint (logout,
		clutter_align_constraint_new (stage, CLUTTER_ALIGN_X_AXIS, 1.0f));
	g_signal_connect (logout, "button-press-event", G_CALLBACK (on_press), NULL);
	g_signal_connect (logout, "button-release-event", G_CALLBACK (on_release), NULL);
	g_signal_connect (logout, "enter-event", G_CALLBACK (on_enter), NULL);
	clutter_actor_insert_child_above (stage, logout, backdrop);
	clutter_actor_show (stage);
	pump (200);

	clutter_actor_get_transformed_position (logout, &x, &y);
	w = clutter_actor_get_width (logout);
	h = clutter_actor_get_height (logout);
	picked = clutter_stage_get_actor_at_pos (
		CLUTTER_STAGE (stage), CLUTTER_PICK_REACTIVE, x + w / 2.0f, y + h / 2.0f);
	g_printerr (
		"text mapped=%d size=%.0fx%.0f at=%.0f,%.0f picked=%s\n",
		clutter_actor_is_mapped (logout),
		w, h, x, y,
		picked == logout ? "text" : (picked == NULL ? "null" : G_OBJECT_TYPE_NAME (picked)));

	sprite_before = meta_cursor_tracker_get_sprite (tracker);
	pointer = clutter_seat_create_virtual_device (seat, CLUTTER_POINTER_DEVICE);
	click_at (pointer, x + w / 2.0f, y + h / 2.0f);
	g_printerr (
		"baseline enter=%d press=%d release=%d sprite %p\n",
		enter_count, press_count, release_count,
		(void *) sprite_before);
	if (release_count < 1) {
		g_printerr ("FAIL logout-text-pointer-gate: release=0\n");
		failed = 1;
	}

	g_signal_connect (logout, "enter-event", G_CALLBACK (on_enter_pointer), NULL);
	g_signal_connect (logout, "leave-event", G_CALLBACK (on_leave_default), NULL);
	clutter_virtual_input_device_notify_absolute_motion (
		pointer, g_get_monotonic_time (), 8, 8);
	pump (50);
	sprite_away = meta_cursor_tracker_get_sprite (tracker);
	clutter_virtual_input_device_notify_absolute_motion (
		pointer, g_get_monotonic_time (), x + w / 2.0f, y + h / 2.0f);
	pump (50);
	sprite_hover = meta_cursor_tracker_get_sprite (tracker);
	g_printerr (
		"pointer sprite away=%p hover=%p\n",
		(void *) sprite_away, (void *) sprite_hover);
	if (sprite_hover == NULL || sprite_hover == sprite_away) {
		g_printerr ("FAIL logout-text-pointer-gate: cursor unchanged\n");
		failed = 1;
	}
	if (failed) {
		return 1;
	}
	g_printerr ("PASS logout-text-pointer-gate\n");
	return 0;
}
