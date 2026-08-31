/* Namespace helpers Shell/St use; GIR often omits these from per-type headers. */
#include "clutter/clutter-enums.h"
#include "clutter/clutter-types.h"

G_BEGIN_DECLS

ClutterTextDirection clutter_get_default_text_direction (void);
guint32 clutter_get_current_event_time (void);
ClutterBackend * clutter_get_default_backend (void);
guint clutter_threads_add_repaint_func (ClutterRepaintFlags flags,
                                        GSourceFunc func,
                                        gpointer data,
                                        GDestroyNotify notify);

G_END_DECLS
