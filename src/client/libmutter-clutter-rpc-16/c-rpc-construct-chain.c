/*
 * Walk parent classes for rpc_construct. A JavaScript class never
 * implements rpc_construct; its slot can hold an inherited or
 * overridden GIR vfunc (such as StWidget.vfunc_style_changed) at the
 * same class-struct offset. Skip every Gjs_ class and call the first
 * C/Vala ancestor's rpc_construct.
 */
/* Meson sets this to the vala_header for the mutter API in this build. */
#include MUTTER_CLUTTER_RPC_HEADER

void
clutter_actor_rpc_construct_chain (ClutterActor *self)
{
	GType type;

	g_return_if_fail (CLUTTER_IS_ACTOR (self));
	type = G_TYPE_FROM_INSTANCE (self);
	while (g_type_is_a (type, CLUTTER_TYPE_ACTOR)) {
		ClutterActorClass *klass;
		GType parent;

		parent = g_type_parent (type);
		if (g_str_has_prefix (g_type_name (type), "Gjs_")) {
			type = parent;
			continue;
		}
		klass = g_type_class_peek (type);
		if (klass != NULL && klass->rpc_construct != NULL) {
			klass->rpc_construct (self);
			return;
		}
		type = parent;
	}
}
