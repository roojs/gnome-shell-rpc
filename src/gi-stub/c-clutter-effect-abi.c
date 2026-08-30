/*
 * Minimal GTypes only — instance sizes match stock G_DECLARE_DERIVABLE
 * (24 bytes). Vala always embeds TypePrivate*, so these three parents cannot
 * be Vala classes if libshell C subclasses them (ShellGLSLEffect).
 *
 * Method symbols (RPC relays) live in Vala — see ClutterEffectRelay.vala.
 */

#include "gsr-clutter-effect-abi.h"
#include <glib-object.h>

static void clutter_actor_meta_class_init (ClutterActorMetaClass *klass) { }
static void clutter_actor_meta_init (ClutterActorMeta *self) { }
G_DEFINE_TYPE (ClutterActorMeta, clutter_actor_meta, G_TYPE_INITIALLY_UNOWNED)

static void clutter_effect_class_init (ClutterEffectClass *klass) { }
static void clutter_effect_init (ClutterEffect *self) { }
G_DEFINE_TYPE (ClutterEffect, clutter_effect, CLUTTER_TYPE_ACTOR_META)

static void clutter_offscreen_effect_class_init (ClutterOffscreenEffectClass *klass) { }
static void clutter_offscreen_effect_init (ClutterOffscreenEffect *self) { }
G_DEFINE_TYPE (ClutterOffscreenEffect, clutter_offscreen_effect, CLUTTER_TYPE_EFFECT)
