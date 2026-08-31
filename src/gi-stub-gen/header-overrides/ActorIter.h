/* Curated ClutterActorIter (0.7.4) — opaque fields + St-used method protos. */

#include <glib-object.h>
#include "clutter/clutter-types.h"

G_BEGIN_DECLS

struct _ClutterActorIter
{
  gpointer dummy1;
  gpointer dummy2;
  gint32 dummy3;
  gpointer dummy4;
  gpointer dummy5;
};

GType clutter_actor_iter_get_type (void);

void clutter_actor_iter_init (ClutterActorIter * iter, ClutterActor * root);
gboolean clutter_actor_iter_next (ClutterActorIter * iter, ClutterActor ** child);
gboolean clutter_actor_iter_prev (ClutterActorIter * iter, ClutterActor ** child);
void clutter_actor_iter_remove (ClutterActorIter * iter);
void clutter_actor_iter_destroy (ClutterActorIter * iter);
gboolean clutter_actor_iter_is_valid (const ClutterActorIter * iter);
