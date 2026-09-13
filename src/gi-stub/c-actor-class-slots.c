#include "gsr-actor-class-slots.h"

void
gsr_actor_class_measure_slots(
	GType type,
	void **get_preferred_width,
	void **get_preferred_height,
	void **allocate)
{
	GsrClutterActorClassMeasureSlots *klass =
		g_type_class_peek(type);
	if (get_preferred_width != NULL) {
		*get_preferred_width = klass != NULL
			? (void *) klass->get_preferred_width : NULL;
	}
	if (get_preferred_height != NULL) {
		*get_preferred_height = klass != NULL
			? (void *) klass->get_preferred_height : NULL;
	}
	if (allocate != NULL) {
		*allocate = klass != NULL
			? (void *) klass->allocate : NULL;
	}
}
