/* Thin wrapper — Vala cannot pass ClutterModifierSet by value cleanly. */
#include "gsr-clutter-event-key.h"

ClutterEvent *
gsr_clutter_event_key_new (ClutterEventType type,
                           uint32_t keyval,
                           ClutterModifierType modifiers)
{
	GsrClutterModifierSet raw = { 0, 0, 0 };
	return clutter_event_key_new (type,
	                              (ClutterEventFlags) (1 << 1),
	                              0,
	                              NULL,
	                              raw,
	                              modifiers,
	                              keyval,
	                              0,
	                              0,
	                              0);
}
