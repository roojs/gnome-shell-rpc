/* Private mutter Clutter event ctors — exported from libmutter-clutter but
 * not in the public clutter-event.h. Used by Helper-FocusManager. */
#pragma once

#include <clutter/clutter.h>

G_BEGIN_DECLS

typedef struct {
	ClutterModifierType pressed;
	ClutterModifierType latched;
	ClutterModifierType locked;
} GsrClutterModifierSet;

ClutterEvent * clutter_event_key_new (ClutterEventType     type,
                                      ClutterEventFlags    flags,
                                      int64_t              timestamp_us,
                                      ClutterInputDevice  *source_device,
                                      GsrClutterModifierSet raw_modifiers,
                                      ClutterModifierType  modifiers,
                                      uint32_t             keyval,
                                      uint32_t             evcode,
                                      uint32_t             keycode,
                                      gunichar             unicode_value);

ClutterEvent * gsr_clutter_event_key_new (ClutterEventType type,
                                          uint32_t keyval,
                                          ClutterModifierType modifiers);

G_END_DECLS
