/*
 * Show Applications leaves the grid unallocated because its server
 * peer is an StWidget. StScrollView.set_child requires StScrollable.
 * StViewport is. A widget is not.
 *
 * The fixed shape, beside this file: a StViewport subclass. Its
 * allocate runs, then the stock viewport allocate runs. That is the
 * peer IconGrid needs. Product src stays unchanged.
 *
 *   meson compile -C build tests/call-sync-repro/viewport-scrollable-peer-gate
 *   timeout 20 ./build/tests/call-sync-repro/viewport-scrollable-peer-gate
 */
#include <clutter/clutter.h>
#include <meta/meta-backend.h>
#include <meta/meta-context.h>
#include <meta/meta-plugin.h>
#include <st/st-scroll-view.h>
#include <st/st-viewport.h>
#include <st/st-widget.h>
#include <string.h>

typedef struct _GatePlugin {
	MetaPlugin parent;
} GatePlugin;

typedef struct _GatePluginClass {
	MetaPluginClass parent_class;
} GatePluginClass;

G_DEFINE_TYPE (GatePlugin, gate_plugin, META_TYPE_PLUGIN)

static int scrollable_criticals;

typedef struct {
	int hits;
	float width;
	float height;
} GateHits;

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

static void
on_log (
	const gchar *log_domain,
	GLogLevelFlags flags,
	const gchar *message,
	gpointer user_data
) {
	(void) log_domain;
	(void) user_data;
	if ((flags & G_LOG_LEVEL_CRITICAL) != 0
			&& message != NULL
			&& strstr (message, "ST_IS_SCROLLABLE") != NULL) {
		scrollable_criticals++;
	}
	g_log_default_handler (log_domain, flags, message, user_data);
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
gate_viewport_allocate (ClutterActor *actor, const ClutterActorBox *box)
{
	GateHits *hits = g_object_get_data (G_OBJECT (actor), "gate-hits");
	ClutterActorClass *parent;

	hits->hits++;
	hits->width = box->x2 - box->x1;
	hits->height = box->y2 - box->y1;
	parent = g_type_class_peek (ST_TYPE_VIEWPORT);
	parent->allocate (actor, box);
}

static void
gate_viewport_class_init (gpointer klass, gpointer data)
{
	(void) data;
	CLUTTER_ACTOR_CLASS (klass)->allocate = gate_viewport_allocate;
}

static void
gate_viewport_init (GObject *self)
{
	GateHits *hits = g_new0 (GateHits, 1);
	g_object_set_data_full (self, "gate-hits", hits, g_free);
}

static GType
gate_viewport_get_type (void)
{
	static GType type = 0;
	GTypeQuery query;
	GTypeInfo info;

	if (type != 0) {
		return type;
	}
	g_type_query (ST_TYPE_VIEWPORT, &query);
	memset (&info, 0, sizeof (info));
	info.class_size = query.class_size;
	info.class_init = gate_viewport_class_init;
	info.instance_size = query.instance_size;
	info.instance_init = (GInstanceInitFunc) gate_viewport_init;
	type = g_type_register_static (
		ST_TYPE_VIEWPORT, "GateViewport", &info, 0);
	return type;
}

static int
fail (const char *reason)
{
	g_printerr ("FAIL viewport-scrollable-peer-gate: %s\n", reason);
	return 1;
}

int
main (int argc, char **argv)
{
	char *args[] = {
		"viewport-scrollable-peer-gate",
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
	ClutterActor *stage;
	StWidget *widget;
	StScrollView *widget_scroll;
	StScrollView *peer_scroll;
	ClutterActor *peer;
	GateHits *hits;
	ClutterActorBox box;
	int criticals_before;

	(void) argc;
	(void) argv;

	context = meta_create_context ("viewport-scrollable-peer-gate");
	meta_context_set_plugin_gtype (context, gate_plugin_get_type ());
	if (!meta_context_configure (context, &n, &av, &error)) {
		return fail (error->message);
	}
	if (!meta_context_setup (context, &error)) {
		return fail (error->message);
	}
	if (!meta_context_start (context, &error)) {
		return fail (error->message);
	}

	g_log_set_default_handler (on_log, NULL);
	stage = meta_backend_get_stage (meta_context_get_backend (context));

	widget = g_object_new (ST_TYPE_WIDGET, NULL);
	widget_scroll = ST_SCROLL_VIEW (st_scroll_view_new ());
	criticals_before = scrollable_criticals;
	st_scroll_view_set_child (widget_scroll, (StScrollable *) widget);
	if (scrollable_criticals != criticals_before + 1) {
		return fail ("widget set_child did not assert ST_IS_SCROLLABLE");
	}
	if (st_scroll_view_get_child (widget_scroll) != NULL) {
		return fail ("widget became the scroll child");
	}
	if (clutter_actor_get_n_children (CLUTTER_ACTOR (widget_scroll)) != 2) {
		return fail ("widget scroll child count");
	}
	g_printerr ("ok widget rejected children=2\n");

	peer = g_object_new (gate_viewport_get_type (), NULL);
	clutter_actor_set_x_expand (peer, TRUE);
	clutter_actor_set_y_expand (peer, TRUE);
	clutter_actor_set_layout_manager (peer, clutter_bin_layout_new ());
	peer_scroll = ST_SCROLL_VIEW (st_scroll_view_new ());
	criticals_before = scrollable_criticals;
	st_scroll_view_set_child (peer_scroll, ST_SCROLLABLE (peer));
	if (scrollable_criticals != criticals_before) {
		return fail ("viewport subclass set_child asserted");
	}
	if (st_scroll_view_get_child (peer_scroll) != ST_SCROLLABLE (peer)) {
		return fail ("viewport subclass was not the scroll child");
	}
	if (clutter_actor_get_n_children (CLUTTER_ACTOR (peer_scroll)) != 3) {
		return fail ("viewport scroll child count");
	}
	g_printerr ("ok viewport subclass accepted children=3\n");

	clutter_actor_add_child (stage, CLUTTER_ACTOR (peer_scroll));
	clutter_actor_set_position (CLUTTER_ACTOR (peer_scroll), 0, 194);
	clutter_actor_set_size (CLUTTER_ACTOR (peer_scroll), 800, 315);
	clutter_actor_show (stage);
	clutter_actor_show (CLUTTER_ACTOR (peer_scroll));
	pump (200);
	box.x1 = 0;
	box.y1 = 194;
	box.x2 = 800;
	box.y2 = 509;
	clutter_actor_allocate (CLUTTER_ACTOR (peer_scroll), &box);

	hits = g_object_get_data (G_OBJECT (peer), "gate-hits");
	clutter_actor_get_allocation_box (peer, &box);
	g_printerr (
		"peer hits=%d seen=%.0fx%.0f alloc=%.0fx%.0f mapped=%d\n",
		hits->hits,
		hits->width,
		hits->height,
		box.x2 - box.x1,
		box.y2 - box.y1,
		clutter_actor_is_mapped (peer));
	if (hits->hits < 1 || hits->width < 100 || hits->height < 100) {
		return fail ("viewport allocate did not see the scroll box");
	}
	if (!clutter_actor_is_mapped (peer)) {
		return fail ("viewport stayed unmapped");
	}
	if ((box.x2 - box.x1) < 100 || (box.y2 - box.y1) < 100) {
		return fail ("viewport allocation stayed empty");
	}

	g_printerr ("PASS viewport-scrollable-peer-gate\n");
	return 0;
}
