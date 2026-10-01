/*
 * Boxed GType for ClutterFrame. Do not include clutter.h (enum clash).
 */
#pragma once

#include <glib-object.h>

GType clutter_frame_get_type (void);

#define CLUTTER_TYPE_FRAME (clutter_frame_get_type ())
