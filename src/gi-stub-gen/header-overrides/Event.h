/* Curated ClutterEvent header body (0.7.4).
 * Spliced by gi-stub-gen after the generated banner — GIR size is 0 and stock
 * macros (EVENT_STOP / button ids) are not in the typelib.
 * Method prototypes are still emitted from GIR after this body.
 */

#include <glib-object.h>
#include "clutter/clutter-types.h"
#include "clutter/clutter-enums.h"

G_BEGIN_DECLS

#define CLUTTER_TYPE_EVENT (clutter_event_get_type ())

#define CLUTTER_EVENT_PROPAGATE (FALSE)
#define CLUTTER_EVENT_STOP (TRUE)

#define CLUTTER_BUTTON_PRIMARY (1)
#define CLUTTER_BUTTON_MIDDLE (2)
#define CLUTTER_BUTTON_SECONDARY (3)

/* Opaque — St only needs ClutterEvent * (typedef in clutter-types.h). */
union _ClutterEvent
{
  guint8 _gsr_opaque;
};
