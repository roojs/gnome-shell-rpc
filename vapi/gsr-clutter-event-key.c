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

ClutterEvent *
gsr_clutter_event_key_insert (ClutterEventType type,
                              uint32_t keyval,
                              ClutterModifierType modifiers)
{
	GsrClutterModifierSet raw = { 0, 0, 0 };
	return clutter_event_key_new (type,
	                              CLUTTER_EVENT_FLAG_SYNTHETIC,
	                              0,
	                              NULL,
	                              raw,
	                              modifiers,
	                              keyval,
	                              0,
	                              0,
	                              clutter_keysym_to_unicode (keyval));
}

ClutterEvent *
gsr_clutter_event_key_im (ClutterEventType type,
                          uint32_t time_ms,
                          ClutterModifierType modifiers,
                          uint32_t keyval,
                          gunichar unicode_value)
{
	GsrClutterModifierSet raw = { 0, 0, 0 };

	if (unicode_value == 0)
		unicode_value = clutter_keysym_to_unicode (keyval);
	return clutter_event_key_new (type,
	                              CLUTTER_EVENT_FLAG_INPUT_METHOD,
	                              (int64_t) time_ms * 1000,
	                              NULL,
	                              raw,
	                              modifiers,
	                              keyval,
	                              0,
	                              0,
	                              unicode_value);
}
