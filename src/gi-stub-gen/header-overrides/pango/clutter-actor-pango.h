#if !defined(__CLUTTER_H_INSIDE__) && !defined(CLUTTER_COMPILATION)
#error "Only <clutter/clutter.h> can be included directly."
#endif

#include <pango/pango.h>
#include "clutter/clutter-types.h"

G_BEGIN_DECLS

PangoContext * clutter_actor_get_pango_context (ClutterActor * self);
PangoContext * clutter_actor_create_pango_context (ClutterActor * self);
PangoLayout * clutter_actor_create_pango_layout (ClutterActor * self, const gchar * text);

G_END_DECLS
