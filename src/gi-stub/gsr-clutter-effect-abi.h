/*
 * Instance/class layouts matching stock G_DECLARE_DERIVABLE sizes.
 * Do not include clutter.h (enum clashes with Vala mutter-rpc-16.h).
 */
#pragma once

#include <glib-object.h>

GType clutter_actor_meta_get_type (void);
GType clutter_effect_get_type (void);
GType clutter_offscreen_effect_get_type (void);

#define CLUTTER_TYPE_ACTOR_META (clutter_actor_meta_get_type ())
#define CLUTTER_TYPE_EFFECT (clutter_effect_get_type ())
#define CLUTTER_TYPE_OFFSCREEN_EFFECT (clutter_offscreen_effect_get_type ())

typedef struct _ClutterActorMeta ClutterActorMeta;
typedef struct _ClutterActorMetaClass ClutterActorMetaClass;
typedef struct _ClutterEffect ClutterEffect;
typedef struct _ClutterEffectClass ClutterEffectClass;
typedef struct _ClutterOffscreenEffect ClutterOffscreenEffect;
typedef struct _ClutterOffscreenEffectClass ClutterOffscreenEffectClass;

struct _ClutterActorMeta {
	GInitiallyUnowned parent_instance;
};

/* Stock class sizes: ActorMeta=152 Effect=200 OffscreenEffect=224. */
struct _ClutterActorMetaClass {
	GInitiallyUnownedClass parent_class;
	void (*_gsr_pad[2]) (void);
};

struct _ClutterEffect {
	ClutterActorMeta parent_instance;
};

struct _ClutterEffectClass {
	ClutterActorMetaClass parent_class;
	void (*_gsr_pad[6]) (void);
};

struct _ClutterOffscreenEffect {
	ClutterEffect parent_instance;
};

struct _ClutterOffscreenEffectClass {
	ClutterEffectClass parent_class;
	void (*_gsr_pad[3]) (void);
};
