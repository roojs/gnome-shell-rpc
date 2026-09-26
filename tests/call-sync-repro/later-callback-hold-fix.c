#include <glib-object.h>

static int live_laters;

static void
later_callback_hold_closure_gone (gpointer data, GClosure *closure)
{
  (void) data;
  (void) closure;
  live_laters--;
}

void
later_callback_hold_ref_source_func (GSourceFunc func, gpointer target, int times)
{
  (void) func;
  if (target == NULL || times <= 0) {
    return;
  }
  for (int i = 0; i < times; i++) {
    g_closure_ref (target);
  }
}

int
later_callback_hold_source_func_refs (GSourceFunc func, gpointer target)
{
  (void) func;
  if (target == NULL) {
    return -1;
  }
  return (int) ((GClosure *) target)->ref_count;
}

void
later_callback_hold_watch_source_func (GSourceFunc func, gpointer target)
{
  (void) func;
  if (target == NULL) {
    return;
  }
  live_laters++;
  g_closure_add_finalize_notifier (target, NULL, later_callback_hold_closure_gone);
}

void
later_callback_hold_unref_surplus (GSourceFunc func, gpointer target)
{
  (void) func;
  if (target == NULL) {
    return;
  }
  GClosure *closure = target;
  while (closure->ref_count > 1) {
    g_closure_unref (closure);
  }
}

int
later_callback_hold_live_closures (void)
{
  return live_laters;
}
