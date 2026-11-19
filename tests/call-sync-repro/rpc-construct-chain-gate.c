/*
 * Gate: clutter_actor_rpc_construct_chain skips a Gjs_ class only when
 * klass->rpc_construct != parent_klass->rpc_construct. A 3-level GJS
 * subclass whose parent overrode StWidget.vfunc_style_changed (colliding
 * with ClutterActorClass.rpc_construct) but whose leaf did not
 * (FolderGrid -> AppGrid -> IconGrid -> StViewport) inherits the parent's
 * vfunc pointer, so klass->rpc_construct == parent_klass->rpc_construct
 * and the walk invokes AppGrid.vfunc_style_changed() during construct
 * instead of StViewport.rpc_construct().
 *
 * meson compile -C build rpc-construct-chain-gate
 * timeout 5 ./build/tests/call-sync-repro/rpc-construct-chain-gate current
 * timeout 5 ./build/tests/call-sync-repro/rpc-construct-chain-gate fixed
 */

#include <glib-object.h>
#include <stdio.h>
#include <string.h>

typedef struct _TestActor TestActor;
typedef struct _TestActorClass TestActorClass;

struct _TestActor {
	GObject parent_instance;
};

struct _TestActorClass {
	GObjectClass parent_class;
	void (*rpc_construct) (TestActor *self);
};

G_DEFINE_TYPE (TestActor, test_actor, G_TYPE_OBJECT)

static int viewport_construct_calls = 0;
static int style_changed_calls = 0;

static void
test_actor_default_rpc_construct (TestActor *self)
{
	(void) self;
}

static void
test_actor_class_init (TestActorClass *klass)
{
	klass->rpc_construct = test_actor_default_rpc_construct;
}

static void
test_actor_init (TestActor *self)
{
	(void) self;
}

typedef struct _TestViewport {
	TestActor parent_instance;
} TestViewport;

typedef struct _TestViewportClass {
	TestActorClass parent_class;
} TestViewportClass;

G_DEFINE_TYPE (TestViewport, test_viewport, test_actor_get_type ())

static void
viewport_rpc_construct (TestActor *self)
{
	(void) self;
	viewport_construct_calls++;
}

static void
test_viewport_class_init (TestViewportClass *klass)
{
	((TestActorClass *) klass)->rpc_construct = viewport_rpc_construct;
}

static void
test_viewport_init (TestViewport *self)
{
	(void) self;
}

static void
icon_grid_style_changed (TestActor *self)
{
	(void) self;
	style_changed_calls++;
}

static void
app_grid_style_changed (TestActor *self)
{
	(void) self;
	style_changed_calls++;
}

static void
gjs_icon_grid_class_init (gpointer g_class, gpointer class_data)
{
	(void) class_data;
	((TestActorClass *) g_class)->rpc_construct = icon_grid_style_changed;
}

static void
gjs_app_grid_class_init (gpointer g_class, gpointer class_data)
{
	(void) class_data;
	((TestActorClass *) g_class)->rpc_construct = app_grid_style_changed;
}

static void
gjs_folder_grid_class_init (gpointer g_class, gpointer class_data)
{
	(void) g_class;
	(void) class_data;
}

static void
walk_current (TestActor *self)
{
	GType actor_type = test_actor_get_type ();
	GType type = G_TYPE_FROM_INSTANCE (self);

	while (g_type_is_a (type, actor_type)) {
		TestActorClass *klass = g_type_class_peek (type);
		GType parent = g_type_parent (type);
		TestActorClass *parent_klass = NULL;

		if (g_type_is_a (parent, actor_type))
			parent_klass = g_type_class_peek (parent);
		if (klass != NULL && klass->rpc_construct != NULL) {
			if (parent_klass != NULL
					&& klass->rpc_construct != parent_klass->rpc_construct
					&& g_str_has_prefix (g_type_name (type), "Gjs_")) {
				type = parent;
				continue;
			}
			klass->rpc_construct (self);
			return;
		}
		type = parent;
	}
}

static void
walk_fixed (TestActor *self)
{
	GType actor_type = test_actor_get_type ();
	GType type = G_TYPE_FROM_INSTANCE (self);

	while (g_type_is_a (type, actor_type)) {
		TestActorClass *klass;
		GType parent = g_type_parent (type);

		if (g_str_has_prefix (g_type_name (type), "Gjs_")) {
			type = parent;
			continue;
		}
		klass = g_type_class_peek (type);
		if (klass != NULL && klass->rpc_construct != NULL) {
			klass->rpc_construct (self);
			return;
		}
		type = parent;
	}
}

static GType
register_gjs_type (const char *name, GType parent, GClassInitFunc class_init)
{
	GTypeInfo info = {
		.class_size = sizeof (TestViewportClass),
		.class_init = class_init,
		.instance_size = sizeof (TestViewport),
	};
	return g_type_register_static (parent, name, &info, 0);
}

int
main (int argc, char **argv)
{
	const char *mode = argc >= 2 ? argv[1] : "current";
	if (strcmp (mode, "current") != 0 && strcmp (mode, "fixed") != 0) {
		fprintf (stderr, "FAIL rpc-construct-chain-gate: mode %s\n", mode);
		return 2;
	}

	GType icon_grid = register_gjs_type (
		"Gjs_IconGrid", test_viewport_get_type (), gjs_icon_grid_class_init);
	GType app_grid = register_gjs_type (
		"Gjs_AppGrid", icon_grid, gjs_app_grid_class_init);
	GType folder_grid = register_gjs_type (
		"Gjs_FolderGrid", app_grid, gjs_folder_grid_class_init);

	TestActor *obj = g_object_new (folder_grid, NULL);
	if (strcmp (mode, "current") == 0)
		walk_current (obj);
	else
		walk_fixed (obj);
	g_object_unref (obj);

	if (viewport_construct_calls != 1 || style_changed_calls != 0) {
		fprintf (stderr,
			"FAIL rpc-construct-chain-gate %s: viewport=%d style_changed=%d\n",
			mode, viewport_construct_calls, style_changed_calls);
		return 1;
	}
	fprintf (stderr,
		"PASS rpc-construct-chain-gate %s: viewport=%d style_changed=%d\n",
		mode, viewport_construct_calls, style_changed_calls);
	return 0;
}
