/*
 * A GSourceFunc's user_data is the GClosure. g_closure_ref takes that
 * pointer alone; Vala always passes the function pointer as well.
 */

#include <glib-object.h>

GClosure *
gsr_closure_ref (GSourceFunc func, gpointer target)
{
  (void) func;
  if (target == NULL) {
    return NULL;
  }
  return g_closure_ref (target);
}
