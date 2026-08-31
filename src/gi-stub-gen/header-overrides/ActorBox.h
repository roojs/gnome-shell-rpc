/* Curated ClutterActorBox (0.7.4) — fields + St-used method protos / macros.
 * GIR methods still append after this body if not already listed.
 */

#include <glib-object.h>
#include <graphene.h>
#include "clutter/clutter-types.h"

G_BEGIN_DECLS

#define CLUTTER_ACTOR_BOX_INIT(x_1, y_1, x_2, y_2) \
  { (x_1), (y_1), (x_2), (y_2) }
#define CLUTTER_ACTOR_BOX_INIT_ZERO \
  CLUTTER_ACTOR_BOX_INIT (0.f, 0.f, 0.f, 0.f)

struct _ClutterActorBox
{
  gfloat x1;
  gfloat y1;
  gfloat x2;
  gfloat y2;
};

GType clutter_actor_box_get_type (void);

ClutterActorBox * clutter_actor_box_new (gfloat x_1, gfloat y_1, gfloat x_2, gfloat y_2);
ClutterActorBox * clutter_actor_box_alloc (void);
ClutterActorBox * clutter_actor_box_init (ClutterActorBox * box, gfloat x_1, gfloat y_1, gfloat x_2, gfloat y_2);
void clutter_actor_box_init_rect (ClutterActorBox * box, gfloat x, gfloat y, gfloat width, gfloat height);
ClutterActorBox * clutter_actor_box_copy (const ClutterActorBox * box);
void clutter_actor_box_free (ClutterActorBox * box);
gboolean clutter_actor_box_equal (const ClutterActorBox * box_a, const ClutterActorBox * box_b);
gfloat clutter_actor_box_get_x (const ClutterActorBox * box);
gfloat clutter_actor_box_get_y (const ClutterActorBox * box);
gfloat clutter_actor_box_get_width (const ClutterActorBox * box);
gfloat clutter_actor_box_get_height (const ClutterActorBox * box);
void clutter_actor_box_get_origin (const ClutterActorBox * box, gfloat * x, gfloat * y);
void clutter_actor_box_get_size (const ClutterActorBox * box, gfloat * width, gfloat * height);
gfloat clutter_actor_box_get_area (const ClutterActorBox * box);
gboolean clutter_actor_box_contains (const ClutterActorBox * box, gfloat x, gfloat y);
void clutter_actor_box_from_vertices (ClutterActorBox * box, const graphene_point3d_t verts[]);
void clutter_actor_box_interpolate (const ClutterActorBox * initial, const ClutterActorBox * final, gdouble progress, ClutterActorBox * result);
void clutter_actor_box_clamp_to_pixel (ClutterActorBox * box);
void clutter_actor_box_union (const ClutterActorBox * a, const ClutterActorBox * b, ClutterActorBox * result);
void clutter_actor_box_set_origin (ClutterActorBox * box, gfloat x, gfloat y);
void clutter_actor_box_set_size (ClutterActorBox * box, gfloat width, gfloat height);
void clutter_actor_box_scale (ClutterActorBox * box, gfloat scale);
gboolean clutter_actor_box_is_initialized (ClutterActorBox * box);

G_DEFINE_AUTOPTR_CLEANUP_FUNC (ClutterActorBox, clutter_actor_box_free)
