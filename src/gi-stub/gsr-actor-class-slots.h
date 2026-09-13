#pragma once
#include <glib-object.h>

/*
 * Prefix of ClutterActorClass through allocate — enough to read the three
 * measure slots. Do not include clutter-actor.h (enum / type soup).
 * Layout must match generated clutter/clutter-actor.h Class fields.
 */
typedef struct {
	GInitiallyUnownedClass parent_class;
	/* show … pick (11 slots) before get_preferred_width */
	void (*_pad_before_measure[11])(void);
	void (*get_preferred_width)(void);
	void (*get_preferred_height)(void);
	void (*allocate)(void);
} GsrClutterActorClassMeasureSlots;

void gsr_actor_class_measure_slots(
	GType type,
	void **get_preferred_width,
	void **get_preferred_height,
	void **allocate);
