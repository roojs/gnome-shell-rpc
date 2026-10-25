/*
 * Walk parent classes for rpc_construct. A JavaScript class can
 * leave a different function in that slot than its parent. Calling
 * that function runs style handling. Skip it and keep walking.
 */
#include "mutter-clutter-rpc-16.h"

void
clutter_actor_rpc_construct_chain (ClutterActor *self)
{
	GType type;

	g_return_if_fail (CLUTTER_IS_ACTOR (self));
	type = G_TYPE_FROM_INSTANCE (self);
	while (g_type_is_a (type, CLUTTER_TYPE_ACTOR)) {
		ClutterActorClass *klass;
		ClutterActorClass *parent_klass;
		GType parent;

		klass = g_type_class_peek (type);
		parent = g_type_parent (type);
		parent_klass = NULL;
		if (g_type_is_a (parent, CLUTTER_TYPE_ACTOR))
			parent_klass = g_type_class_peek (parent);
		if (klass != NULL && klass->rpc_construct != NULL) {
			if (parent_klass != NULL
					&& klass->rpc_construct != parent_klass->rpc_construct
					&& g_str_has_prefix (g_type_name (type), "Gjs_")) {
				type = parent;
				continue;
			}
			klass->rpc_construct (self);
			return;
		}
		type = parent;
	}
}
