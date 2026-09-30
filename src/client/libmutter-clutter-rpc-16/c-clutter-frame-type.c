/**
 * Boxed GType for opaque ClutterFrame. copy/free are Compact methods in
 * Clutter.override.vala. Do not include clutter.h (enum clash).
 */
#include "gsr-clutter-effect-abi.h"

gpointer clutter_frame_copy (gpointer frame);
void clutter_frame_free (gpointer frame);

GType
clutter_frame_get_type (void)
{
	static gsize init = 0;
	static GType type = 0;

	if (g_once_init_enter (&init)) {
		type = g_boxed_type_register_static (
			"ClutterFrame",
			(GBoxedCopyFunc) clutter_frame_copy,
			(GBoxedFreeFunc) clutter_frame_free);
		g_once_init_leave (&init, 1);
	}
	return type;
}
