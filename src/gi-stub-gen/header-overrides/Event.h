/* Curated ClutterEvent header body (0.7.4 / B3).
 * Spliced by gi-stub-gen after the generated banner — GIR size is 0 and stock
 * macros (EVENT_STOP / button ids) are not in the typelib.
 * Method prototypes are still emitted from GIR after this body.
 *
 * typedef in clutter-types.h is union _ClutterEvent; layout matches Vala
 * Compact Event (event_type cname "type", then x, y, button).
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

union _ClutterEvent
{
	struct {
		ClutterEventType type;
		float x;
		float y;
		guint32 button;
		guint32 state;
		guint32 keyval;
	};
};
