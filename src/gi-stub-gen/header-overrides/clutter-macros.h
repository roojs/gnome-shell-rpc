/* Curated clutter-macros.h (0.7.4) — export/no-op + type macros + autoptr. */

#include <glib-object.h>
#include "clutter/clutter-types.h"

#ifndef CLUTTER_EXPORT
#define CLUTTER_EXPORT
#endif

#ifndef CLUTTER_CURRENT_TIME
#define CLUTTER_CURRENT_TIME (0L)
#endif

#ifndef CLUTTER_TYPE_MARGIN
#define CLUTTER_TYPE_MARGIN (clutter_margin_get_type ())
GType clutter_margin_get_type (void);
#endif

#ifndef CLUTTER_TYPE_ACTOR_BOX
#define CLUTTER_TYPE_ACTOR_BOX (clutter_actor_box_get_type ())
GType clutter_actor_box_get_type (void);
#endif

#ifndef CLUTTER_TEXT_BUFFER_MAX_SIZE
#define CLUTTER_TEXT_BUFFER_MAX_SIZE G_MAXUSHORT
#endif

void clutter_paint_volume_free (ClutterPaintVolume * pv);

G_DEFINE_AUTOPTR_CLEANUP_FUNC (ClutterActor, g_object_unref)
G_DEFINE_AUTOPTR_CLEANUP_FUNC (ClutterActorAccessible, g_object_unref)
G_DEFINE_AUTOPTR_CLEANUP_FUNC (ClutterShaderEffect, g_object_unref)
G_DEFINE_AUTOPTR_CLEANUP_FUNC (ClutterContent, g_object_unref)
G_DEFINE_AUTOPTR_CLEANUP_FUNC (ClutterPaintNode, g_object_unref)
G_DEFINE_AUTOPTR_CLEANUP_FUNC (ClutterTransition, g_object_unref)
G_DEFINE_AUTOPTR_CLEANUP_FUNC (ClutterPaintVolume, clutter_paint_volume_free)
G_DEFINE_AUTOPTR_CLEANUP_FUNC (ClutterEffect, g_object_unref)
G_DEFINE_AUTOPTR_CLEANUP_FUNC (ClutterOffscreenEffect, g_object_unref)
G_DEFINE_AUTOPTR_CLEANUP_FUNC (ClutterLayoutManager, g_object_unref)
G_DEFINE_AUTOPTR_CLEANUP_FUNC (ClutterTextBuffer, g_object_unref)
