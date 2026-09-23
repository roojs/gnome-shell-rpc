/*
 * TEMPORARY ABI bridge.
 *
 * valac groups virtual methods and signal class closures separately in the
 * generated class struct.  Stock Clutter interleaves them, so a normal Vala
 * virtual call can read the wrong slot after GJS installs vfunc_* at the
 * typelib offset.  Invoke the stock-offset slot directly until generated
 * class structs are emitted without valac reordering.
 */

#include <glib-object.h>

typedef gboolean (*BoolPointerVfunc) (gpointer instance,
                                      gpointer argument);
typedef void (*VoidPointerVfunc) (gpointer instance,
                                  gpointer argument);
typedef void (*PreferredSizeVfunc) (gpointer instance,
                                    gfloat   for_size,
                                    gfloat  *minimum,
                                    gfloat  *natural);
typedef void (*VoidVfunc) (gpointer instance);

static gpointer
vfunc_at (gpointer instance,
          gint     offset)
{
  gpointer *slot;

  g_return_val_if_fail (G_IS_OBJECT (instance), NULL);
  g_return_val_if_fail (offset >= 0, NULL);

  slot = (gpointer *) (((guint8 *) G_OBJECT_GET_CLASS (instance)) + offset);
  return *slot;
}

gboolean
gsr_vfunc_call_bool_pointer (gpointer instance,
                             gint     offset,
                             gpointer argument)
{
  BoolPointerVfunc function = vfunc_at (instance, offset);

  return function != NULL ? function (instance, argument) : FALSE;
}

void
gsr_vfunc_call_void_pointer (gpointer instance,
                             gint     offset,
                             gpointer argument)
{
  VoidPointerVfunc function = vfunc_at (instance, offset);

  if (function != NULL)
    function (instance, argument);
}

void
gsr_vfunc_call_preferred_size (gpointer instance,
                               gint     offset,
                               gfloat   for_size,
                               gfloat  *minimum,
                               gfloat  *natural)
{
  PreferredSizeVfunc function = vfunc_at (instance, offset);

  if (function != NULL)
    function (instance, for_size, minimum, natural);
}

void
gsr_vfunc_call_void (gpointer instance,
                     gint     offset)
{
  VoidVfunc function = vfunc_at (instance, offset);

  if (function != NULL)
    function (instance);
}
