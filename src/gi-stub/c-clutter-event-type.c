/**
 * GJS requires ClutterEvent registered as boxed ("Unions must currently be
 * registered as boxed types"). Vala Compact emits copy/free but not get_type
 * when the C header already prototypes clutter_event_get_type.
 */
#include <glib-object.h>
#include "clutter/clutter.h"

GType
clutter_event_get_type (void)
{
	static gsize init = 0;
	static GType type = 0;

	if (g_once_init_enter (&init)) {
		type = g_boxed_type_register_static (
			"ClutterEvent",
			(GBoxedCopyFunc) clutter_event_copy,
			(GBoxedFreeFunc) clutter_event_free);
		g_once_init_leave (&init, 1);
	}
	return type;
}
